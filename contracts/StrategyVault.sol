// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IOracle.sol";

contract StrategyVault is
    Initializable,
    ERC20,
    ReentrancyGuard,
    Ownable
{
    IOracle public oracle;
    address public strategist;

    uint256 public totalAssets;
    uint256 public lockedFunds;
    uint256 public performanceFeeBps;

    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Bet {
        uint256 matchId;
        uint256 amount;
        bool predictedOutcome;
        bool settled;
    }

    Bet[] public bets;
    mapping(address => uint256) public depositTimestamp;

    /// @notice Initializer instead of constructor (required for clones)
    function initialize(
        address _oracle,
        address _strategist,
        uint256 _performanceFeeBps
    ) external initializer {
        require(_oracle != address(0), "Invalid oracle");
        require(_strategist != address(0), "Invalid strategist");
        require(_performanceFeeBps <= 2_000, "Fee too high");

        oracle = IOracle(_oracle);
        strategist = _strategist;
        performanceFeeBps = _performanceFeeBps;

        _transferOwnership(_strategist);
    }

    // ------------------------
    // Deposits / Withdrawals
    // ------------------------

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");

        uint256 shares;
        if (totalSupply() == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * totalSupply()) / totalAssets;
        }

        totalAssets += msg.value;
        depositTimestamp[msg.sender] = block.timestamp;

        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(
            block.timestamp >= depositTimestamp[msg.sender] + 1 days,
            "Funds locked"
        );

        uint256 amount = (shares * totalAssets) / totalSupply();
        uint256 available = address(this).balance - lockedFunds;

        require(amount <= available, "Funds locked in bets");

        totalAssets -= amount;
        _burn(msg.sender, shares);

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ETH transfer failed");
    }

    // ------------------------
    // Betting Logic
    // ------------------------

    function placeBet(
        uint256 matchId,
        bool predictedOutcome,
        uint256 amount
    ) external onlyOwner {
        require(
            amount <= address(this).balance - lockedFunds,
            "Insufficient free funds"
        );

        lockedFunds += amount;

        bets.push(
            Bet({
                matchId: matchId,
                amount: amount,
                predictedOutcome: predictedOutcome,
                settled: false
            })
        );
    }

    function settleBet(uint256 betId) external onlyOwner nonReentrant {
        Bet storage bet = bets[betId];
        require(!bet.settled, "Already settled");

        (bool resolved, bool outcome) = oracle.getMatchResult(bet.matchId);
        require(resolved, "Match not resolved");

        bet.settled = true;
        lockedFunds -= bet.amount;

        if (bet.predictedOutcome == outcome) {
            uint256 profit = bet.amount;
            totalAssets += profit;

            uint256 fee = (profit * performanceFeeBps) / BPS_DENOMINATOR;
            uint256 feeShares = (fee * totalSupply()) / totalAssets;

            _mint(strategist, feeShares);
        } else {
            totalAssets -= bet.amount;
        }
    }

    receive() external payable {}
}
