// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleMarket} from "../src/SimpleMarket.sol";
import {ISimpleMarket} from "../src/interfaces/IArena.sol";
import {MockLeaderboard} from "./mocks/MockLeaderboard.sol";

/// @title SimpleMarket — tests unitaires/exemples
/// @notice Couvre l'émission d'événements, les getters et les rejets d'ordres.
/// _Requirements: 5.5, 5.6, 5.7_
contract SimpleMarketTest is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AGENT_ID = 42;

    SimpleMarket internal market;
    MockLeaderboard internal lb;
    address internal controller = address(0xC0FFEE);

    function setUp() public {
        lb = new MockLeaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        market.setFactory(address(this));
        market.registerAgent(AGENT_ID, controller, 1_000_000e18);
    }

    // ── Prix initial (Req 5.6) ──
    function test_currentPriceStrictlyPositive() public view {
        assertEq(market.currentPrice(), 1e18); // 1:1 au départ
        assertGt(market.currentPrice(), 0);
    }

    // ── Achat : émission de TradeExecuted (Req 5.7) ──
    function test_buyEmitsTradeExecuted() public {
        uint256 qty = 10e18;
        uint256 price = market.currentPrice();
        vm.expectEmit(true, false, false, true);
        emit ISimpleMarket.TradeExecuted(AGENT_ID, uint8(0), qty, price, block.number);
        vm.prank(controller);
        market.buy(AGENT_ID, qty);
        assertEq(lb.updateCalls(), 1); // leaderboard mis à jour dans la même tx (Req 7.2)
    }

    // ── Vente : émission de TradeExecuted (Req 5.7) ──
    function test_sellEmitsTradeExecuted() public {
        vm.prank(controller);
        market.buy(AGENT_ID, 10e18);

        uint256 price = market.currentPrice();
        vm.expectEmit(true, false, false, true);
        emit ISimpleMarket.TradeExecuted(AGENT_ID, uint8(1), 4e18, price, block.number);
        vm.prank(controller);
        market.sell(AGENT_ID, 4e18);
    }

    // ── Getters capitalOf / positionOf (Req 2.6) ──
    function test_gettersReflectState() public {
        assertEq(market.capitalOf(AGENT_ID), 1_000_000e18);
        assertEq(market.positionOf(AGENT_ID), 0);
        vm.prank(controller);
        uint256 cost = market.buy(AGENT_ID, 100e18);
        assertEq(market.positionOf(AGENT_ID), 100e18);
        assertEq(market.capitalOf(AGENT_ID), 1_000_000e18 - cost);
    }

    // ── Rejet qty == 0 (Req 5.5) ──
    function test_buyZeroQuantityReverts() public {
        vm.prank(controller);
        vm.expectRevert(SimpleMarket.InvalidOrder.selector);
        market.buy(AGENT_ID, 0);
    }

    function test_sellZeroQuantityReverts() public {
        vm.prank(controller);
        vm.expectRevert(SimpleMarket.InvalidOrder.selector);
        market.sell(AGENT_ID, 0);
    }

    // ── Rejet agent non enregistré / actif inconnu (Req 5.5) ──
    function test_tradeUnregisteredAgentReverts() public {
        vm.prank(controller);
        vm.expectRevert(SimpleMarket.NotRegistered.selector);
        market.buy(999, 1e18);
    }

    // ── Autorisation : seul le contrôleur peut trader ──
    function test_nonControllerCannotTrade() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(SimpleMarket.Unauthorized.selector);
        market.buy(AGENT_ID, 1e18);
    }

    // ── Réserves nulles à la construction → revert ──
    function test_constructorRejectsZeroReserves() public {
        vm.expectRevert(SimpleMarket.InvalidReserves.selector);
        new SimpleMarket(address(lb), 0, 1e18);
    }
}
