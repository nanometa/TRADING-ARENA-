// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {TradingAgent} from "../../src/TradingAgent.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../../src/RitualAddresses.sol";

/// Feature: ritual-trading-arena, Property 3: Autorisation des callbacks asynchrones.
///
/// Pour toute adresse expéditrice d'un callback onLLMResult, le TradingAgent traite
/// le résultat si et seulement si msg.sender == AsyncDelivery ; pour toute autre
/// adresse, le callback est rejeté et l'état de l'agent reste inchangé.
///
/// Validates: Requirements 9.8, 9.9
contract Property03_CallbackAuth is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
    }

    function testFuzz_onlyAsyncDeliveryMayCallback(address caller, uint256 jobId) public {
        vm.assume(caller != RitualAddresses.ASYNC_DELIVERY);

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        bytes memory result = abi.encode("BUY");
        vm.prank(caller);
        vm.expectRevert(TradingAgent.BadCallbackSender.selector);
        agent.onLLMResult(0, jobId, result);

        // État inchangé (Req 9.9).
        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee");
    }

    function test_asyncDeliveryAccepted() public {
        // Un appel depuis AsyncDelivery ne revert PAS sur l'autorisation
        // (le job est inconnu → anomalie gérée, mais pas de BadCallbackSender).
        bytes memory result = abi.encode("HOLD");
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onLLMResult(0, 12345, result); // ne doit pas revert
    }
}
