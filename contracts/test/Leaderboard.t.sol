// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Leaderboard} from "../src/Leaderboard.sol";
import {MockMarket} from "./mocks/MockMarket.sol";

/// @title Leaderboard — tests unitaires/exemples
/// _Requirements: 7.5, 7.6, 7.7_
contract LeaderboardTest is Test {
    uint256 internal constant WAD = 1e18;

    Leaderboard internal lb;
    MockMarket internal market;

    function setUp() public {
        lb = new Leaderboard();
        market = new MockMarket();
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(this));
        market.setPrice(WAD);
    }

    // ── scoreOf d'un agent existant (Req 7.6) ──
    function test_scoreOfExistingAgent() public {
        market.setAgent(1, 500e18, 10e18); // prix 1:1 → score = 510e18
        lb.trackAgent(1);
        assertEq(lb.scoreOf(1), 510e18);
    }

    // ── scoreOf d'un agent inexistant → revert AgentNotFound (Req 7.7) ──
    function test_scoreOfMissingAgentReverts() public {
        vm.expectRevert(Leaderboard.AgentNotFound.selector);
        lb.scoreOf(999);
    }

    // ── ranking() vide sans erreur (Req 7.5) ──
    function test_emptyRanking() public view {
        (uint256[] memory ids, uint256[] memory scores) = lb.ranking();
        assertEq(ids.length, 0);
        assertEq(scores.length, 0);
    }

    // ── Agent exposé immédiatement avec score nul (Req 7.3 contexte) ──
    function test_trackAgentZeroScoreExposed() public {
        market.setAgent(2, 0, 0);
        lb.trackAgent(2);
        (uint256[] memory ids,) = lb.ranking();
        assertEq(ids.length, 1);
        assertEq(ids[0], 2);
        assertEq(lb.scoreOf(2), 0);
    }

    // ── updateScore recalcule après changement (Req 7.2) ──
    function test_updateScoreRecomputes() public {
        market.setAgent(3, 100e18, 0);
        lb.trackAgent(3);
        assertEq(lb.scoreOf(3), 100e18);

        market.setAgent(3, 100e18, 50e18); // +50 unités à prix 1:1
        lb.updateScore(3);
        assertEq(lb.scoreOf(3), 150e18);
    }

    // ── updateScore réservé au scoreUpdater/owner ──
    function test_updateScoreUnauthorizedReverts() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(Leaderboard.Unauthorized.selector);
        lb.updateScore(1);
    }

    // ── Classement ordonné : exemple concret ──
    function test_rankingOrderedExample() public {
        market.setAgent(1, 300e18, 0);
        market.setAgent(2, 500e18, 0);
        market.setAgent(3, 500e18, 0); // égalité avec agent 2
        lb.trackAgent(1);
        lb.trackAgent(2);
        lb.trackAgent(3);

        (uint256[] memory ids, uint256[] memory scores) = lb.ranking();
        // 500(id2), 500(id3), 300(id1) — égalité départagée par id croissant
        assertEq(ids[0], 2);
        assertEq(ids[1], 3);
        assertEq(ids[2], 1);
        assertEq(scores[0], 500e18);
        assertEq(scores[2], 300e18);
    }
}
