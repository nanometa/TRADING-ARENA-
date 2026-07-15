// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";
import {RitualMocks} from "../helpers/RitualMocks.sol";

/// Feature: ritual-trading-arena, Property 7: Verrouillage du dépôt couvrant le TTL.
///
/// Pour tout appel asynchrone ou planifié avec un ttl donné, le système n'autorise
/// l'exécution (soumission LLM) que si le bloc d'expiration du dépôt RitualWallet
/// est strictement supérieur à currentBlock + ttl ; sinon l'appel est empêché.
///
/// Validates: Requirements 2.4
contract Property07_DepositLockTtl is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
        RitualMocks.mockSchedulerReturns(1);
        RitualMocks.mockApproveScheduler();
    }

    function testFuzz_llmSubmittedIffLockCoversTtl(uint32 ttl, uint256 lockExpiry, uint256 jobId)
        public
    {
        ttl = uint32(bound(ttl, 1, 500)); // MAX_TTL
        lockExpiry = bound(lockExpiry, 0, block.number + 2000);

        // Activer pour fixer scheduleTtl.
        vm.prank(agentOwner);
        agent.activate(100, 10, ttl);

        // Mocks pour atteindre le contrôle du verrou.
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(100e18);
        RitualMocks.mockNoPendingJob(false);
        RitualMocks.mockLLMResponse(_wrappedLLM("HOLD"));

        // Enregistrer le verrou de dépôt.
        vm.prank(agentOwner);
        agent.recordDepositLock(lockExpiry);

        bool shouldSubmit = lockExpiry > block.number + ttl;

        // Modèle in-tx : si le verrou couvre le ttl, le cycle aboutit et persiste
        // (cycleCount=1) ; sinon il s'arrête sur DepositLockTooShort AVANT toute
        // soumission LLM (cycleCount=0).
        _wake(1);

        (, , uint64 cycleCount,) = agent.strategyState();
        if (shouldSubmit) {
            assertEq(cycleCount, 1, "LLM soumis (cycle persiste) quand le verrou couvre le ttl");
        } else {
            assertEq(cycleCount, 0, "LLM non soumis quand le verrou est trop court");
        }
    }
}
