// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {MockMarket} from "../mocks/MockMarket.sol";

/// Feature: ritual-trading-arena, Property 15: Invariante d'ordre du leaderboard.
///
/// Pour tout ensemble d'agents avec leurs scores, le classement retourné est
/// ordonné par score décroissant, les scores égaux étant départagés par
/// identifiant d'agent croissant ; l'ensemble vide retourne un classement vide
/// sans erreur.
///
/// Validates: Requirements 7.4, 7.5
contract Property15_RankingOrder is Test {
    uint256 internal constant WAD = 1e18;

    Leaderboard internal lb;
    MockMarket internal market;

    function setUp() public {
        lb = new Leaderboard();
        market = new MockMarket();
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(this));
        market.setPrice(WAD); // prix 1:1 → score = capital (position 0)
    }

    /// @dev L'ensemble vide retourne un classement vide sans erreur (Req 7.5).
    function test_emptyRankingNoError() public view {
        (uint256[] memory ids, uint256[] memory scores) = lb.ranking();
        assertEq(ids.length, 0);
        assertEq(scores.length, 0);
    }

    /// @dev Avec n agents aux scores arbitraires, le classement est trié par score
    ///      décroissant, égalités départagées par agentId croissant.
    function testFuzz_rankingOrderInvariant(uint256 seed, uint8 count) public {
        uint256 n = bound(count, 1, 5); // 3-5 agents de démo, on couvre 1..5

        for (uint256 i = 0; i < n; i++) {
            uint256 agentId = i + 1; // ids 1..n croissants
            uint256 sc = bound(uint256(keccak256(abi.encode(seed, i))), 0, 1_000_000e18);
            // score = capital (position 0, prix 1:1)
            market.setAgent(agentId, sc, 0);
            lb.trackAgent(agentId);
        }

        (uint256[] memory ids, uint256[] memory scores) = lb.ranking();
        assertEq(ids.length, n, "longueur classement");

        // Vérifier l'invariant d'ordre pour chaque paire adjacente.
        for (uint256 k = 1; k < ids.length; k++) {
            bool ok;
            if (scores[k - 1] != scores[k]) {
                ok = scores[k - 1] > scores[k]; // score décroissant
            } else {
                ok = ids[k - 1] < ids[k]; // égalité → agentId croissant
            }
            assertTrue(ok, "ordre du classement respecte score desc puis id asc");
        }
    }
}
