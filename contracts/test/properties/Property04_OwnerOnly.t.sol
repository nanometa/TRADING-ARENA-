// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {TradingAgent} from "../../src/TradingAgent.sol";
import {AgentFactory} from "../../src/AgentFactory.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 4: Opérations privilégiées réservées à l'owner.
///
/// Pour toute adresse appelante différente de l'owner d'un TradingAgent, toute
/// opération privilégiée (pause, reprise, retrait, arrêt d'urgence, retrait
/// d'urgence, configuration) est rejetée et l'état du TradingAgent reste inchangé.
/// Couvre aussi AgentFactory.retireAgent par un non-owner.
///
/// Validates: Requirements 1.8, 9.3, 9.4
contract Property04_OwnerOnly is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    function testFuzz_nonOwnerCannotPause(address caller) public {
        vm.assume(caller != agentOwner);
        vm.prank(caller);
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.pause();
        assertFalse(agent.paused(), "etat pause inchange");
    }

    function testFuzz_nonOwnerCannotEmergencyStop(address caller) public {
        vm.assume(caller != agentOwner);
        vm.prank(caller);
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.emergencyStop();
        assertFalse(agent.emergencyStopped(), "arret urgence inchange");
    }

    function testFuzz_nonOwnerCannotSetBudget(address caller) public {
        vm.assume(caller != agentOwner);
        vm.prank(caller);
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.setBudgetLimit(1e18, 3600);
    }

    function testFuzz_nonOwnerCannotEmergencyWithdraw(address caller) public {
        vm.assume(caller != agentOwner);
        vm.prank(caller);
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.emergencyWithdraw();
    }

    function testFuzz_nonOwnerCannotRetireViaFactory(address caller) public {
        vm.assume(caller != agentOwner);
        vm.prank(caller);
        vm.expectRevert(AgentFactory.Unauthorized.selector);
        factory.retireAgent(agentId);
    }
}
