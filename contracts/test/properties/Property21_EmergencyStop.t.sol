// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 21: L'arrêt d'urgence stoppe l'engagement de capital.
///
/// Pour tout agent dont l'arrêt d'urgence est actif, aucun cycle ultérieur n'engage
/// de capital : tous les trades sont refusés tant que l'arrêt reste actif.
///
/// Validates: Requirements 9.5
contract Property21_EmergencyStop is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    /// @dev Même une décision BUY livrée pendant un arrêt d'urgence n'engage aucun capital.
    function testFuzz_emergencyStopBlocksCapital(uint256 jobId) public {
        // Décision BUY préparée ; arrêt d'urgence actif AVANT le cycle.
        _primeHappyPathWith(jobId, "BUY");
        vm.prank(agentOwner);
        agent.emergencyStop();

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        // BUY décodée EN-TX, mais l'arrêt d'urgence bloque tout engagement de capital.
        _wake(1);

        assertEq(market.capitalOf(agentId), capBefore, "capital inchange sous arret urgence");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee sous arret urgence");
    }
}
