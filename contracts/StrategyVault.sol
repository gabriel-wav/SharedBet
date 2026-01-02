// contracts/StrategyVault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOracle.sol";

contract StrategyVault is
    Initializable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    IOracle public oracle;
    IERC20 public asset; // O Token (USDC)
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

    function initialize(
        address _asset, // USDC Address
        address _oracle,
        address _strategist,
        uint256 _performanceFeeBps
    ) external initializer {
        __ERC20_init("SharedBet Token", "SBT");
        __ReentrancyGuard_init();
        __Ownable_init(_strategist);

        require(_asset != address(0), "Invalid asset");
        require(_oracle != address(0), "Invalid oracle");
        require(_strategist != address(0), "Invalid strategist");
        require(_performanceFeeBps <= 2_000, "Fee too high");

        asset = IERC20(_asset);
        oracle = IOracle(_oracle);
        strategist = _strategist;
        performanceFeeBps = _performanceFeeBps;
    }

    // Agora o depósito exige aprovação prévia do USDC e valor como argumento
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero deposit");
        
        // Puxa o USDC do usuário para o cofre
        asset.transferFrom(msg.sender, address(this), amount);

        uint256 shares;
        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply()) / totalAssets;
        }

        totalAssets += amount;
        depositTimestamp[msg.sender] = block.timestamp;

        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(
            block.timestamp >= depositTimestamp[msg.sender] + 1 days,
            "Funds locked"
        );
        uint256 amount = (shares * totalAssets) / totalSupply();
        uint256 available = asset.balanceOf(address(this)) - lockedFunds;
        require(amount <= available, "Funds locked in bets");

        totalAssets -= amount;
        _burn(msg.sender, shares);

        // Envia USDC de volta
        asset.transfer(msg.sender, amount);
    }

    function placeBet(
        uint256 matchId,
        bool predictedOutcome,
        uint256 amount
    ) external onlyOwner {
        require(
            amount <= asset.balanceOf(address(this)) - lockedFunds,
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
            uint256 profit = bet.amount; // Simplificação: lucro = aposta (odds 2.0 fixas na lógica interna atual)
            // Se o lucro viesse de fora, precisaria de transferFrom aqui. 
            // Assumindo que o dinheiro 'apareceu' ou é contabilidade interna:
            totalAssets += profit;

            uint256 fee = (profit * performanceFeeBps) / BPS_DENOMINATOR;
            uint256 feeShares = (fee * totalSupply()) / totalAssets;
            _mint(strategist, feeShares);
        } else {
            totalAssets -= bet.amount;
        }
    }
}