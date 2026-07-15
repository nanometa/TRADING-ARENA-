// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {MockLeaderboard} from "../mocks/MockLeaderboard.sol";

/// Feature: ritual-trading-arena, Property 9: Conservation du capital et de la
/// valeur de position sur un trade valide.
///
/// Pour tout trade valide (achat/vente) exécuté au prix courant p, la valeur
/// totale du portefeuille `capital + position * p` est conservée par l'opération
/// au prix p (à l'arrondi entier WAD près du produit qty*price).
///
/// Validates: Requirements 5.2, 5.3, 6.5
contract Property09_TradeConservation is Test {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant AGENT_ID = 1;

    SimpleMarket internal market;
    MockLeaderboard internal lb;
    address internal controller = address(0xC0FFEE);

    function setUp() public {
        lb = new MockLeaderboard();
        // Réserves larges pour limiter le slippage et garder le prix stable.
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        market.setFactory(address(this));
        market.registerAgent(AGENT_ID, controller, 1_000_000e18);
    }

    /// @dev La valeur du portefeuille évaluée au prix AVANT le trade est conservée
    ///      (à la troncature entière de qty*price/WAD près), pour un achat puis une vente.
    function testFuzz_tradeConservesPortfolioValue(uint256 buyQty, uint256 sellFrac) public {
        // Bornes : quantités strictement positives et bien inférieures à la réserve.
        buyQty = bound(buyQty, 1e18, 100_000e18);

        uint256 priceBefore = market.currentPrice();
        uint256 capBefore = market.capitalOf(AGENT_ID);
        uint256 posBefore = market.positionOf(AGENT_ID);
        uint256 valueBefore = capBefore + (posBefore * priceBefore) / WAD;

        // ── Achat ──
        vm.prank(controller);
        uint256 cost = market.buy(AGENT_ID, buyQty);

        uint256 capAfterBuy = market.capitalOf(AGENT_ID);
        uint256 posAfterBuy = market.positionOf(AGENT_ID);

        // Comptabilité exacte de l'achat (Req 5.2).
        assertEq(capAfterBuy, capBefore - cost, "capital apres achat");
        assertEq(posAfterBuy, posBefore + buyQty, "position apres achat");

        // Conservation au prix d'exécution : valeur evaluee a `priceBefore` inchangee
        // a la troncature pres (cost = floor(qty*priceBefore/WAD)).
        uint256 valueAfterBuy = capAfterBuy + (posAfterBuy * priceBefore) / WAD;
        // L'écart est uniquement dû à l'arrondi entier du coût (< buyQty au pire).
        assertApproxEqAbs(valueAfterBuy, valueBefore, buyQty, "conservation achat");

        // ── Vente d'une fraction de la position ──
        uint256 sellQty = bound(sellFrac, 1e18, posAfterBuy);
        uint256 priceBeforeSell = market.currentPrice();
        uint256 capBeforeSell = market.capitalOf(AGENT_ID);
        uint256 posBeforeSell = market.positionOf(AGENT_ID);

        vm.prank(controller);
        uint256 proceeds = market.sell(AGENT_ID, sellQty);

        uint256 capAfterSell = market.capitalOf(AGENT_ID);
        uint256 posAfterSell = market.positionOf(AGENT_ID);

        // Comptabilité exacte de la vente (Req 5.3).
        assertEq(capAfterSell, capBeforeSell + proceeds, "capital apres vente");
        assertEq(posAfterSell, posBeforeSell - sellQty, "position apres vente");

        // Conservation au prix de vente.
        uint256 valBeforeSell = capBeforeSell + (posBeforeSell * priceBeforeSell) / WAD;
        uint256 valAfterSell = capAfterSell + (posAfterSell * priceBeforeSell) / WAD;
        assertApproxEqAbs(valAfterSell, valBeforeSell, sellQty, "conservation vente");
    }
}
