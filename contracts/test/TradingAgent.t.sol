// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "./helpers/AgentTestBase.sol";
import {TradingAgent} from "../src/TradingAgent.sol";
import {Strategy} from "../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../src/RitualAddresses.sol";
import {RitualMocks} from "./helpers/RitualMocks.sol";

/// @title TradingAgent — tests d'exemple / intégration mockée
/// @notice Couvre le cycle 2 phases, la découverte TEE non hardcodée, l'indisponibilité
///         TEE, la planification, et l'échec du retrait d'urgence.
/// _Requirements: 3.1, 3.2, 3.6, 3.7, 3.8, 4.1, 4.7, 9.7_
contract TradingAgentTest is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 100_000e18);
    }

    // ── Happy path : décision BUY décodée et trade exécuté DANS LA MÊME TX
    //    (short-running async / fulfilled-replay — skill ritual-dapp-llm) (Req 3.1, 3.2) ──
    function test_buyExecutesTradeInTx() public {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(100e18);
        RitualMocks.mockNoPendingJob(false);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);
        // Sur le replay, le précompile 0x0802 renvoie l'enveloppe LLM réglée ; ici "BUY".
        RitualMocks.mockLLMResponse(_wrappedLLM("BUY"));

        uint256 posBefore = market.positionOf(agentId);
        _wake(1);
        // Trade exécuté dans la même tx : position augmentée.
        assertGt(market.positionOf(agentId), posBefore, "BUY execute un trade dans la meme tx");
    }

    // ── Découverte TEE non hardcodée : l'adresse provient du registre (Req 3.8) ──
    function test_teeDiscoveryUsesRegistryAddress() public {
        // Exécuteur à une adresse arbitraire renvoyée par le mock.
        address customTee = address(0xDEADBEEF);
        RitualMocks.mockTeeRegistryWithExecutor(customTee);
        RitualMocks.mockWalletBalance(100e18);
        RitualMocks.mockNoPendingJob(false);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);
        // Enveloppe LLM "BUY" : si l'exécuteur du registre est bien découvert, le cycle
        // aboutit et le trade s'exécute dans la même tx.
        RitualMocks.mockLLMResponse(_wrappedLLM("BUY"));

        uint256 posBefore = market.positionOf(agentId);
        _wake(1);
        assertGt(market.positionOf(agentId), posBefore, "executeur du registre utilise (cycle aboutit)");
    }

    // ── TEE indisponible : aucun appel, cycle abandonné (Req 3.7) ──
    function test_teeUnavailableAbortsCycle() public {
        uint256 jobId = 557;
        RitualMocks.mockTeeRegistryEmpty(); // aucun exécuteur
        RitualMocks.mockWalletBalance(100e18);
        RitualMocks.mockNoPendingJob(false);
        RitualMocks.mockLLMReturns(jobId);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);

        _wake(1);
        (, , , , bool pending) = agent.pendingDecisions(jobId);
        assertFalse(pending, "aucun job soumis sans executeur TEE");
    }

    // ── Planification : activate appelle le Scheduler et mémorise le callId (Req 4.1) ──
    function test_activateSchedules() public {
        RitualMocks.mockSchedulerReturns(4242);
        bytes memory scheduledData = abi.encodeWithSelector(
            agent.autoCycle.selector, uint256(0), uint256(0)
        );
        vm.expectCall(
            RitualAddresses.SCHEDULER,
            abi.encodeWithSignature(
                "schedule(bytes,uint32,uint32,uint32,uint32,uint32,uint256,uint256,uint256,address)",
                scheduledData,
                uint32(3_500_000),
                uint32(block.number) + uint32(170),
                uint32(1),
                uint32(100),
                uint32(200),
                uint256(1_100_000_000),
                uint256(0),
                uint256(0),
                address(agent)
            )
        );
        vm.prank(agentOwner);
        agent.activate(100, 1, 200);
        assertEq(agent.callId(), 4242, "callId memorise");
        assertEq(agent.scheduleTtl(), 200, "ttl memorise");
        assertEq(agent.scheduleNumCalls(), 1, "serie one-shot pour le LLM");
        assertFalse(agent.autoReschedule(), "replanification desactivee par defaut");
    }

    function test_ownerCanEnableAutoRescheduleExplicitly() public {
        vm.prank(agentOwner);
        agent.setAutoReschedule(true);
        assertTrue(agent.autoReschedule(), "owner active le mode continu explicitement");
    }

    // ── Soft-skip (fix autopilote) : si le commit LLM 0x0802 échoue (ex. expéditeur
    //    momentanément verrouillé), le cycle se termine proprement SANS revert et SANS
    //    trade — au lieu de gaspiller le gas planifié. ──
    function test_failedLlmCommitSkipsCleanly() public {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(100e18);
        RitualMocks.mockNoPendingJob(false);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);
        // Le précompile LLM échoue (call revert) → _submitLLM doit soft-skip (pas de revert).
        vm.mockCallRevert(RitualAddresses.LLM_PRECOMPILE, bytes(""), "sender locked");

        uint256 posBefore = market.positionOf(agentId);
        uint256 capBefore = market.capitalOf(agentId);
        _wake(1); // ne doit PAS revert
        assertEq(market.positionOf(agentId), posBefore, "position inchangee (soft-skip)");
        assertEq(market.capitalOf(agentId), capBefore, "capital inchange (soft-skip)");
    }

    function test_llmEnvelopeErrorTripsCircuitBreakerWithoutFakeHold() public {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(100e18);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);
        RitualMocks.mockLLMResponse(_wrappedLLMError("vLLM registry unavailable"));

        uint256 posBefore = market.positionOf(agentId);
        uint256 capBefore = market.capitalOf(agentId);
        _wake(1);

        assertTrue(agent.paused(), "circuit breaker actif");
        assertEq(agent.consecutiveLlmErrors(), 1, "erreur LLM comptabilisee");
        assertEq(market.positionOf(agentId), posBefore, "aucun trade");
        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
        (, , uint64 cycleCount, bool initialized) = agent.strategyState();
        assertEq(cycleCount, 0, "pas de faux cycle HOLD persiste");
        assertFalse(initialized, "etat non initialise par une erreur");
    }

    function test_lowFeeEscrowPausesBeforeLlmCall() public {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(0.03e18);
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);

        _wake(1);

        assertTrue(agent.paused(), "agent coupe avant de bruler les frais");
        assertEq(agent.estimatedCallCost(), 0.35e18, "seuil LLM avec marge");
    }

    function test_ownerCannotLowerSafeFeeReserve() public {
        vm.prank(agentOwner);
        vm.expectRevert(TradingAgent.UnsafeFeeReserve.selector);
        agent.setEstimatedCallCost(0.03e18);
    }

    // ── Échec du retrait d'urgence : revert, état inchangé (Req 9.7) ──
    function test_emergencyWithdrawFailureReverts() public {
        // Le wallet refuse les transferts : on mocke un échec sur emergencyWithdraw().
        vm.mockCallRevert(
            walletAddr, abi.encodeWithSignature("emergencyWithdraw()"), "withdraw boom"
        );
        vm.prank(agentOwner);
        vm.expectRevert(TradingAgent.WithdrawFailed.selector);
        agent.emergencyWithdraw();
    }

    // ── autoCycle réservé au Scheduler ──
    function test_autoCycleOnlyScheduler() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.autoCycle(1, 0);
    }
}
