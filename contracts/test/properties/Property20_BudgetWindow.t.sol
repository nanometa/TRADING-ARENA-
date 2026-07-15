// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 20: Plafond du budget sur fenêtre glissante.
///
/// Pour toute séquence de trades sur une fenêtre glissante, le capital cumulé
/// effectivement engagé ne dépasse jamais le Budget_Limit applicable ; tout trade
/// qui ferait dépasser ce plafond est refusé dans sa totalité, le capital reste
/// inchangé et un événement de dépassement horodaté est émis.
///
/// Validates: Requirements 9.1, 9.2
contract Property20_BudgetWindow is AgentTestBase {
    uint256 internal constant WAD = 1e18;

    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 1_000_000e18);
    }

    /// @dev Avec un budget serré, le capital engagé cumulé ne dépasse jamais la limite.
    function testFuzz_cumulativeSpendNeverExceedsLimit(uint256 limit, uint8 nTrades) public {
        // tradeSize par défaut = 1e18 ; prix initial = 1e18 → coût ≈ 1e18 par achat.
        uint256 tradeCost = (agent.tradeSize() * market.currentPrice()) / WAD;
        // Budget_Limit STRICTEMENT POSITIF (Req 9.1) : de 1 à ~10 trades.
        // (limit == 0 signifie « budget non configuré / sans contrainte », hors périmètre
        // de cette propriété qui porte sur un Budget_Limit applicable.)
        limit = bound(limit, 1, tradeCost * 10);
        uint256 n = bound(nTrades, 1, 20);

        vm.prank(agentOwner);
        agent.setBudgetLimit(limit, 1 hours);

        uint256 capInitial = market.capitalOf(agentId);

        for (uint256 i = 0; i < n; i++) {
            // Décision BUY décodée EN-TX à chaque cycle ; le budget glissant la plafonne.
            _primeHappyPathWith(1000 + i, "BUY");
            _wake(uint256(i + 1));
        }

        // Le capital engagé total (capInitial - capital courant) ne dépasse pas la limite,
        // arrondi à un multiple de tradeCost.
        uint256 spent = capInitial - market.capitalOf(agentId);
        assertLe(spent, limit, "capital engage <= Budget_Limit");
    }
}
