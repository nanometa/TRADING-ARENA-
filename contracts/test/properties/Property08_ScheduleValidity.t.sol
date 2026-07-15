// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {TradingAgent} from "../../src/TradingAgent.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../../src/RitualAddresses.sol";
import {RitualMocks} from "../helpers/RitualMocks.sol";

/// Feature: ritual-trading-arena, Property 8: Validité des paramètres de planification.
///
/// Pour tout triplet (frequency, numCalls, ttl), l'activation réussit si et
/// seulement si frequency>=1, numCalls>=1, frequency×numCalls<=MAX_LIFESPAN(10000)
/// et 1<=ttl<=MAX_TTL(500) ; tout paramètre hors bornes provoque un rejet sans
/// planification enregistrée.
///
/// Validates: Requirements 4.4, 4.5, 4.6
contract Property08_ScheduleValidity is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 10_000e18);
        RitualMocks.mockSchedulerReturns(777); // schedule() renvoie un callId
        RitualMocks.mockApproveScheduler();
    }

    function testFuzz_activationRespectsBounds(uint32 frequency, uint32 numCalls, uint32 ttl)
        public
    {
        // Bornage pour explorer autour des limites.
        frequency = uint32(bound(frequency, 0, 20000));
        numCalls = uint32(bound(numCalls, 0, 20000));
        ttl = uint32(bound(ttl, 0, 1000));

        bool valid = frequency >= 1 && numCalls >= 1
            && uint256(frequency) * uint256(numCalls) <= RitualAddresses.MAX_LIFESPAN && ttl >= 1
            && ttl <= RitualAddresses.MAX_TTL;

        vm.prank(agentOwner);
        if (valid) {
            agent.activate(frequency, numCalls, ttl);
            assertEq(agent.callId(), 777, "planification enregistree");
            assertEq(agent.scheduleTtl(), ttl, "ttl memorise");
        } else {
            vm.expectRevert(TradingAgent.ScheduleLimitExceeded.selector);
            agent.activate(frequency, numCalls, ttl);
            assertEq(agent.callId(), 0, "aucune planification");
        }
    }
}
