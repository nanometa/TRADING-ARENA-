// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {MockLeaderboard} from "../mocks/MockLeaderboard.sol";

/// Feature: ritual-trading-arena, Property 10: Rejet atomique des ordres invalides.
///
/// Pour tout ordre dont le coût total dépasse le capital disponible (achat) ou
/// dont la quantité dépasse la position détenue (vente), l'ordre est rejeté dans
/// sa totalité, sans exécution partielle : capital et position restent inchangés.
///
/// Validates: Requirements 5.4
contract Property10_AtomicReject is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AGENT_ID = 7;

    SimpleMarket internal market;
    MockLeaderboard internal lb;
    address internal controller = address(0xBEEF);

    function setUp() public {
        lb = new MockLeaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        market.setFactory(address(this));
        // Capital modeste pour rendre les dépassements faciles à générer.
        market.registerAgent(AGENT_ID, controller, 1_000e18);
    }

    /// @dev Un achat dont le coût dépasse le capital est rejeté sans mutation.
    function testFuzz_overBudgetBuyReverts(uint256 qty) public {
        uint256 price = market.currentPrice();
        uint256 cap = market.capitalOf(AGENT_ID);

        // Quantité dont le coût dépasse strictement le capital, mais < réserve.
        uint256 minQtyOverBudget = ((cap * WAD) / price) + 2;
        qty = bound(qty, minQtyOverBudget, 500_000e18);

        uint256 capBefore = market.capitalOf(AGENT_ID);
        uint256 posBefore = market.positionOf(AGENT_ID);

        vm.prank(controller);
        vm.expectRevert(SimpleMarket.InsufficientFundsOrPosition.selector);
        market.buy(AGENT_ID, qty);

        assertEq(market.capitalOf(AGENT_ID), capBefore, "capital inchange");
        assertEq(market.positionOf(AGENT_ID), posBefore, "position inchangee");
    }

    /// @dev Une vente dont la quantité dépasse la position est rejetée sans mutation.
    function testFuzz_overPositionSellReverts(uint256 sellQty) public {
        // L'agent n'a aucune position au départ → toute vente > 0 dépasse.
        sellQty = bound(sellQty, 1, 1_000_000e18);

        uint256 capBefore = market.capitalOf(AGENT_ID);
        uint256 posBefore = market.positionOf(AGENT_ID);

        vm.prank(controller);
        vm.expectRevert(SimpleMarket.InsufficientFundsOrPosition.selector);
        market.sell(AGENT_ID, sellQty);

        assertEq(market.capitalOf(AGENT_ID), capBefore, "capital inchange");
        assertEq(market.positionOf(AGENT_ID), posBefore, "position inchangee");
    }
}
