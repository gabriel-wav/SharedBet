// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IOracle.sol";

contract MockOracle is IOracle {
    address public admin;

    struct Match {
        bool resolved;
        bool outcome;
    }

    mapping(uint256 => Match) public matches;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not oracle admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function setMatchResult(
        uint256 matchId,
        bool outcome
    ) external onlyAdmin {
        matches[matchId] = Match(true, outcome);
    }

    function getMatchResult(
        uint256 matchId
    ) external view override returns (bool, bool) {
        Match memory m = matches[matchId];
        return (m.resolved, m.outcome);
    }
}
