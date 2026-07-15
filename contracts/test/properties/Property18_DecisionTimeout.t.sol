// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 18: Le dépassement de délai mène à « ne rien faire ».
///
/// Pour toute décision en attente dont le résultat n'arrive pas dans la fenêtre de
/// blocs équivalente à 60 secondes après l'obtention du jobId, le cycle est
/// abandonné, la décision retenue est « ne rien faire » et l'état de l'agent reste
/// inchangé.
///
/// Validates: Requirements 3.5
contract Property18_DecisionTimeout is AgentTestBase {
    uint64 internal constant TIMEOUT_BLOCKS = 171; // ≈ 60 s à ~350 ms/bloc

    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    function testFuzz_lateResultYieldsHold(uint256 jobId, uint256 extraBlocks) public {
        // Préparer un job en attente.
        _primeHappyPath(jobId);
        _wake(1);

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        // Avancer au-delà de la fenêtre de timeout.
        extraBlocks = bound(extraBlocks, 1, 100_000);
        vm.roll(block.number + TIMEOUT_BLOCKS + extraBlocks);

        // Livrer une décision BUY tardive — doit être ignorée (HOLD).
        _deliver(jobId, "BUY");

        assertEq(market.capitalOf(agentId), capBefore, "capital inchange (timeout)");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee (timeout)");
    }
}
