// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./StrategyVault.sol";

contract StrategyFactory {
    address public immutable implementation;
    address public oracle;

    struct StrategyInfo {
        address vault;
        address strategist;
    }

    StrategyInfo[] public strategies;

    event StrategyCreated(address indexed vault, address indexed strategist);

    constructor(address _oracle) {
        require(_oracle != address(0), "Invalid oracle");
        oracle = _oracle;
        implementation = address(new StrategyVault());
    }

    function createStrategy(
        uint256 performanceFeeBps
    ) external returns (address) {
        address clone = Clones.clone(implementation);

        StrategyVault(payable(clone)).initialize(
            oracle,
            msg.sender,
            performanceFeeBps
        );

        strategies.push(
            StrategyInfo({
                vault: clone,
                strategist: msg.sender
            })
        );

        emit StrategyCreated(clone, msg.sender);
        return clone;
    }

    function strategiesCount() external view returns (uint256) {
        return strategies.length;
    }
}
