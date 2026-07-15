// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentFactory} from "../src/AgentFactory.sol";
import {AgentDeployer} from "../src/AgentDeployer.sol";
import {SimpleMarket} from "../src/SimpleMarket.sol";
import {Leaderboard} from "../src/Leaderboard.sol";
import {AgentRecord} from "../src/interfaces/IArena.sol";
import {Strategy, AgentStatus} from "../src/interfaces/IRitualSystem.sol";

/// @title AgentFactory — tests unitaires/exemples
/// _Requirements: 1.5, 1.6, 1.9, 10.3, 10.4_
contract AgentFactoryTest is Test {
    AgentFactory internal factory;
    SimpleMarket internal market;
    Leaderboard internal lb;

    uint256 internal constant MIN_CAPITAL = 0.01e18;
    uint256 internal constant MAX_CAPITAL = 999_999_999.99e18;

    function setUp() public {
        lb = new Leaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        factory = new AgentFactory(address(market), address(lb), address(new AgentDeployer()));
        market.setFactory(address(factory));
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(market));
        lb.setRegistrar(address(factory));
    }

    function test_implementationVersionIsCurrent() public view {
        assertEq(factory.IMPLEMENTATION_VERSION(), 2);
    }

    // ── Création nominale ──
    function test_createAgentSucceeds() public {
        (uint256 agentId, address agent) = factory.createAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        AgentRecord memory rec = factory.getAgent(agentId);
        assertEq(rec.agent, agent);
        assertEq(rec.owner, address(this));
        assertTrue(rec.strategy == Strategy.TREND_FOLLOWING);
        assertTrue(rec.status == AgentStatus.ACTIVE);
        assertEq(market.capitalOf(agentId), 1_000e18); // capital initial enregistré
    }

    // ── Capital aux bornes valides (Req 1.1, 1.6) ──
    function test_capitalAtBoundsAccepted() public {
        (uint256 id1, ) = factory.createAgent(Strategy.TREND_FOLLOWING, MIN_CAPITAL);
        (uint256 id2, ) = factory.createAgent(Strategy.MEAN_REVERSION, MAX_CAPITAL);
        assertEq(market.capitalOf(id1), MIN_CAPITAL);
        assertEq(market.capitalOf(id2), MAX_CAPITAL);
    }

    // ── Capital sous la borne min → revert (Req 1.6) ──
    function test_capitalBelowMinReverts() public {
        vm.expectRevert(AgentFactory.InvalidInitialCapital.selector);
        factory.createAgent(Strategy.TREND_FOLLOWING, MIN_CAPITAL - 1);
    }

    // ── Capital au-dessus de la borne max → revert (Req 1.6) ──
    function test_capitalAboveMaxReverts() public {
        vm.expectRevert(AgentFactory.InvalidInitialCapital.selector);
        factory.createAgent(Strategy.TREND_FOLLOWING, MAX_CAPITAL + 1);
    }

    // ── Retrait par le propriétaire (Req 1.7) ──
    function test_retireByOwner() public {
        (uint256 agentId, ) = factory.createAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        factory.retireAgent(agentId);
        AgentRecord memory rec = factory.getAgent(agentId);
        assertTrue(rec.status == AgentStatus.RETIRED);
    }

    // ── Retrait par un non-owner → revert (Req 1.8) ──
    function test_retireByNonOwnerReverts() public {
        (uint256 agentId, ) = factory.createAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        vm.prank(address(0xDEAD));
        vm.expectRevert(AgentFactory.Unauthorized.selector);
        factory.retireAgent(agentId);
    }

    // ── Retrait d'un agent déjà retiré → revert (Req 1.9) ──
    function test_retireAlreadyRetiredReverts() public {
        (uint256 agentId, ) = factory.createAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        factory.retireAgent(agentId);
        vm.expectRevert(AgentFactory.AlreadyRetired.selector);
        factory.retireAgent(agentId);
    }

    // ── activeAgentCount reflète les retraits ──
    function test_activeAgentCount() public {
        (uint256 id1, ) = factory.createAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        factory.createAgent(Strategy.MEAN_REVERSION, 1_000e18);
        assertEq(factory.activeAgentCount(), 2);
        factory.retireAgent(id1);
        assertEq(factory.activeAgentCount(), 1);
    }

    // ── Agents de démo : déploiement valide avec < 3 démos autorisé (Req 10.4) ──
    function test_demoBelowThreeAllowed() public {
        factory.createDemoAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        factory.createDemoAgent(Strategy.MEAN_REVERSION, 1_000e18);
        assertEq(factory.demoAgentCount(), 2); // pas d'exigence d'un minimum de 3
    }

    // ── Agents de démo : plafond à 5 (Req 10.3) ──
    function test_demoCapAtFive() public {
        for (uint256 i = 0; i < 5; i++) {
            factory.createDemoAgent(Strategy.TREND_FOLLOWING, 1_000e18);
        }
        assertEq(factory.demoAgentCount(), 5);
        vm.expectRevert(AgentFactory.DemoLimitReached.selector);
        factory.createDemoAgent(Strategy.TREND_FOLLOWING, 1_000e18);
    }

    // ── getAgent d'un agent inexistant → revert ──
    function test_getMissingAgentReverts() public {
        vm.expectRevert(AgentFactory.AgentNotFound.selector);
        factory.getAgent(999);
    }
}
