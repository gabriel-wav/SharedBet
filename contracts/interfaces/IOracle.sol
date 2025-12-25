// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function getMatchResult(
        uint256 matchId
    ) external view returns (bool resolved, bool outcome);
}
