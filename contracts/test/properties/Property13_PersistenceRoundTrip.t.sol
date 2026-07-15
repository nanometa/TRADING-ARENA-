// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 13: Round-trip de persistance/restauration.
///
/// Pour tout état d'agent valide (capital, positions ouvertes, état de stratégie),
/// l'état persisté à la fin d'un cycle est restauré à l'identique au cycle suivant,
/// sans perte ni altération.
///
/// Validates: Requirements 6.1, 6.6
contract Property13_PersistenceRoundTrip is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    /// @dev Après un cycle (HOLD), l'état de stratégie persisté reflète le prix et
    ///      le compteur de cycle ; capital/position (source de vérité marché) sont
    ///      inchangés et donc « restaurés » à l'identique au cycle suivant.
    function testFuzz_persistedStateSurvivesCycle(uint256 jobId) public {
        // Borner pour laisser de la place à jobId+1 (second cycle) sans overflow.
        jobId = bound(jobId, 1, type(uint256).max - 1);

        // Capital/position avant cycle.
        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        // Cycle 1 (HOLD → pas de trade, mais persistance de fin de cycle).
        _primeHappyPath(jobId);
        _wake(1);
        uint256 priceSnap = market.currentPrice();
        _deliver(jobId, "HOLD");

        (uint256 lastPrice, , uint64 cycleCount, bool initialized) = agent.strategyState();
        assertTrue(initialized, "etat initialise");
        assertEq(cycleCount, 1, "compteur de cycle = 1");
        assertEq(lastPrice, priceSnap, "prix persiste");

        // Capital/position inchangés (restaurés à l'identique au cycle suivant).
        assertEq(market.capitalOf(agentId), capBefore, "capital restaure a l'identique");
        assertEq(market.positionOf(agentId), posBefore, "position restauree a l'identique");

        // Cycle 2 : le compteur progresse sans perte de l'état précédent.
        uint256 jobId2 = jobId + 1;
        _primeHappyPath(jobId2);
        _wake(2);
        _deliver(jobId2, "HOLD");
        (, , uint64 cycleCount2, ) = agent.strategyState();
        assertEq(cycleCount2, 2, "compteur de cycle = 2 (pas de reset)");
    }
}
