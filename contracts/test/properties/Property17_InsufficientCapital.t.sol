// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";
import {RitualMocks} from "../helpers/RitualMocks.sol";

/// Feature: ritual-trading-arena, Property 17: Capital insuffisant empêche l'appel.
///
/// Pour tout capital disponible strictement inférieur au coût estimé d'un appel
/// asynchrone ou planifié, l'appel n'est pas exécuté et le capital reste inchangé.
///
/// Validates: Requirements 2.5
contract Property17_InsufficientCapital is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    function testFuzz_insufficientFeesSkipsCall(uint256 balance, uint256 jobId) public {
        uint256 cost = agent.estimatedCallCost();
        balance = bound(balance, 0, cost == 0 ? 0 : cost - 1); // strictement < coût

        // Mocks : TEE dispo, verrou OK, pas de job pending, mais solde de fees insuffisant.
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockNoPendingJob(false);
        RitualMocks.mockLLMReturns(jobId);
        RitualMocks.mockWalletBalance(balance);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);

        uint256 capBefore = market.capitalOf(agentId);

        _wake(1);

        // Aucun job soumis (capital de fees insuffisant) et capital inchangé.
        (, , , , bool pending) = agent.pendingDecisions(jobId);
        assertFalse(pending, "aucun appel LLM soumis");
        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
    }
}
