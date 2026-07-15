// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 12: Atomicité d'un cycle en échec.
///
/// Pour tout cycle de trading qui échoue, aucun trade n'est exécuté et l'état
/// (capital, position) reste identique à l'état d'avant le cycle.
///
/// Validates: Requirements 4.8
contract Property12_CycleAtomicity is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    /// @dev Une vente sans position (cycle voué à l'échec) ne modifie pas l'état.
    function testFuzz_failedSellLeavesStateUnchanged(uint256 jobId) public {
        // Décision SELL décodée EN-TX, mais l'agent n'a aucune position → cycle en échec.
        _primeHappyPathWith(jobId, "SELL");

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);
        assertEq(posBefore, 0, "position initiale nulle");

        _wake(1); // SELL sans position → aucun trade, etat inchange

        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee");
    }
}
