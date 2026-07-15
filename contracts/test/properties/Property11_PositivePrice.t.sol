// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {MockLeaderboard} from "../mocks/MockLeaderboard.sol";

/// Feature: ritual-trading-arena, Property 11: Positivité stricte du prix de marché.
///
/// Pour toute séquence de trades valides appliquée au marché, le prix courant
/// retourné reste strictement positif (> 0).
///
/// Validates: Requirements 5.1, 5.6
contract Property11_PositivePrice is Test {
    uint256 internal constant AGENT_ID = 3;

    SimpleMarket internal market;
    MockLeaderboard internal lb;
    address internal controller = address(0xABCD);

    function setUp() public {
        lb = new MockLeaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        market.setFactory(address(this));
        market.registerAgent(AGENT_ID, controller, 10_000_000e18);
    }

    /// @dev Après une séquence pseudo-aléatoire d'achats/ventes valides, le prix
    ///      reste strictement positif et les réserves restent > 0.
    function testFuzz_priceStaysStrictlyPositive(uint256 seed, uint8 steps) public {
        uint256 nSteps = bound(steps, 1, 30);

        for (uint256 i = 0; i < nSteps; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            bool doBuy = (seed & 1) == 0;
            uint256 pos = market.positionOf(AGENT_ID);

            if (doBuy) {
                // Achat borné pour rester sous le capital et la réserve.
                uint256 qty = bound(seed, 1e18, 50_000e18);
                vm.prank(controller);
                try market.buy(AGENT_ID, qty) {} catch {}
            } else if (pos > 0) {
                uint256 qty = bound(seed, 1, pos);
                vm.prank(controller);
                try market.sell(AGENT_ID, qty) {} catch {}
            }

            // Invariant : prix strictement positif à chaque étape.
            assertGt(market.currentPrice(), 0, "prix > 0");
            assertGt(market.reserveBase(), 0, "reserveBase > 0");
            assertGt(market.reserveQuote(), 0, "reserveQuote > 0");
        }
    }
}
