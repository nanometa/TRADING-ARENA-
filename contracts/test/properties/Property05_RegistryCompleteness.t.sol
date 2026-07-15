// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentFactory} from "../../src/AgentFactory.sol";
import {AgentDeployer} from "../../src/AgentDeployer.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {AgentRecord} from "../../src/interfaces/IArena.sol";
import {Strategy, AgentStatus} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 5: Complétude du registre d'agents.
///
/// Pour toute séquence de k créations d'agents, la liste consultable de la
/// fabrique contient exactement k entrées, et chacune reflète fidèlement
/// l'adresse de l'agent, son owner et son état (actif/retiré).
///
/// Validates: Requirements 1.4
contract Property05_RegistryCompleteness is Test {
    AgentFactory internal factory;
    SimpleMarket internal market;
    Leaderboard internal lb;

    function setUp() public {
        lb = new Leaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        factory = new AgentFactory(address(market), address(lb), address(new AgentDeployer()));
        market.setFactory(address(factory));
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(market));
        lb.setRegistrar(address(factory));
    }

    function testFuzz_registryReflectsAllCreations(uint8 count, uint256 seed) public {
        uint256 k = bound(count, 1, 8);

        address[] memory expectedAgents = new address[](k);
        address[] memory expectedOwners = new address[](k);

        for (uint256 i = 0; i < k; i++) {
            address caller = address(uint160(uint256(keccak256(abi.encode(seed, i, "owner")))));
            vm.assume(caller != address(0));
            Strategy s = (uint256(keccak256(abi.encode(seed, i))) % 2 == 0)
                ? Strategy.TREND_FOLLOWING
                : Strategy.MEAN_REVERSION;

            vm.prank(caller);
            (uint256 agentId, address agent) = factory.createAgent(s, 1_000e18);
            expectedAgents[i] = agent;
            expectedOwners[i] = caller;

            // L'entrée individuelle est fidèle.
            AgentRecord memory rec = factory.getAgent(agentId);
            assertEq(rec.agent, agent, "adresse agent fidele");
            assertEq(rec.owner, caller, "owner fidele");
            assertTrue(rec.status == AgentStatus.ACTIVE, "etat actif a la creation");
        }

        // La liste contient exactement k entrées.
        AgentRecord[] memory list = factory.listAgents();
        assertEq(list.length, k, "exactement k entrees");

        // Chaque entrée correspond à une création (ordre préservé).
        for (uint256 i = 0; i < k; i++) {
            assertEq(list[i].agent, expectedAgents[i], "agent[i]");
            assertEq(list[i].owner, expectedOwners[i], "owner[i]");
        }
    }
}
