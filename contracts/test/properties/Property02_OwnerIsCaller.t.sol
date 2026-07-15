// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentFactory} from "../../src/AgentFactory.sol";
import {AgentDeployer} from "../../src/AgentDeployer.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {AgentRecord} from "../../src/interfaces/IArena.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 2: L'owner enregistré est le soumetteur.
///
/// Pour toute adresse appelante qui crée un agent, l'owner enregistré du
/// TradingAgent résultant est exactement égal à cette adresse appelante.
///
/// Validates: Requirements 1.3
contract Property02_OwnerIsCaller is Test {
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

    function testFuzz_ownerEqualsCaller(address caller, uint256 seed) public {
        vm.assume(caller != address(0));

        Strategy s = (seed % 2 == 0) ? Strategy.TREND_FOLLOWING : Strategy.MEAN_REVERSION;

        vm.prank(caller);
        (uint256 agentId, ) = factory.createAgent(s, 1_000e18);

        AgentRecord memory rec = factory.getAgent(agentId);
        assertEq(rec.owner, caller, "owner = appelant");
    }
}
