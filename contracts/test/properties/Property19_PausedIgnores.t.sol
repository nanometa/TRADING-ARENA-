// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 19: Un agent en pause ou retiré ignore les rappels.
///
/// Pour tout rappel du Scheduler reçu alors que l'agent est en pause ou retiré, le
/// rappel est entièrement ignoré : aucun cycle n'est exécuté, aucun appel LLM n'est
/// émis et l'état reste inchangé.
///
/// Validates: Requirements 4.9
contract Property19_PausedIgnores is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    /// @dev En pause : wakeUp ne touche à rien et ne tente aucun appel système.
    ///      On ne configure AUCUN mock : si l'agent tentait un appel LLM/TEE,
    ///      le test échouerait (appel non mocké).
    function testFuzz_pausedIgnoresWake(uint256 executionIndex) public {
        vm.prank(agentOwner);
        agent.pause();

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);
        uint64 cyclesBefore = _cycleCount();

        _wake(executionIndex); // ne doit rien faire, ne pas revert

        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee");
        assertEq(_cycleCount(), cyclesBefore, "aucun cycle execute");
    }

    function _cycleCount() internal view returns (uint64) {
        (, , uint64 cycleCount, ) = agent.strategyState();
        return cycleCount;
    }
}
