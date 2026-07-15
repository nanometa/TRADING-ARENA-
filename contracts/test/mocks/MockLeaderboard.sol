// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILeaderboard} from "../../src/interfaces/IArena.sol";

/// @title MockLeaderboard
/// @notice Mock minimal du Leaderboard pour les tests de SimpleMarket.
///         Enregistre simplement le nombre d'appels à updateScore et le dernier
///         agentId, sans logique de scoring (testée séparément sur le vrai contrat).
contract MockLeaderboard is ILeaderboard {
    uint256 public updateCalls;
    uint256 public lastAgentId;

    function updateScore(uint256 agentId) external override {
        updateCalls++;
        lastAgentId = agentId;
    }

    function trackAgent(uint256 agentId) external override {
        lastAgentId = agentId;
    }

    function scoreOf(uint256) external pure override returns (uint256) {
        return 0;
    }

    function ranking()
        external
        pure
        override
        returns (uint256[] memory agentIds, uint256[] memory scores)
    {
        agentIds = new uint256[](0);
        scores = new uint256[](0);
    }
}
