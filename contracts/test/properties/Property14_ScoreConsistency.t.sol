// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {MockMarket} from "../mocks/MockMarket.sol";

/// Feature: ritual-trading-arena, Property 14: Cohérence du score (mark-to-market).
///
/// Pour tout agent et tout changement de son capital ou de sa position, le score
/// recalculé est exactement égal à `capital + position × dernierPrix / 1e18`, et
/// cette mise à jour intervient dans la même transaction que l'appel updateScore.
///
/// Validates: Requirements 7.1, 7.2, 7.3
contract Property14_ScoreConsistency is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AGENT_ID = 11;

    Leaderboard internal lb;
    MockMarket internal market;

    function setUp() public {
        lb = new Leaderboard();
        market = new MockMarket();
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(this)); // ce test joue le rôle du marché
    }

    function testFuzz_scoreEqualsMarkToMarket(uint256 capital, uint256 position, uint256 price)
        public
    {
        // Bornes raisonnables pour éviter l'overflow sur position × price.
        capital = bound(capital, 0, 1e30);
        position = bound(position, 0, 1e24);
        price = bound(price, 1, 1e24);

        market.setPrice(price);
        market.setAgent(AGENT_ID, capital, position);

        lb.updateScore(AGENT_ID);

        uint256 expected = capital + (position * price) / WAD;
        assertEq(lb.scoreOf(AGENT_ID), expected, "score = capital + position*prix");
    }
}
