// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "../helpers/AgentTestBase.sol";
import {TradingAgent} from "../../src/TradingAgent.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 6: Totalité du parseur de décision LLM.
///
/// Pour tout résultat LLM brut (bytes arbitraires), la traduction produit
/// exactement une valeur de l'ensemble fermé { acheter, vendre, ne rien faire } ;
/// si le résultat n'est pas interprétable, la décision est « ne rien faire » et
/// l'état de l'agent reste inchangé.
///
/// Validates: Requirements 3.3, 3.4
contract Property06_DecisionParser is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.MEAN_REVERSION, 10_000e18);
    }

    /// @dev Pour des bytes arbitraires livrés en Phase 2 (job inconnu), le callback
    ///      ne revert jamais et l'état reste inchangé (le parseur ne casse pas).
    function testFuzz_arbitraryResultNeverReverts(bytes memory raw, uint256 jobId) public {
        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        // Job inconnu → traité comme anomalie, aucun effet, aucun revert.
        _deliverRaw(jobId, raw);

        assertEq(market.capitalOf(agentId), capBefore, "capital inchange");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee");
    }

    /// @dev Une chaîne non reconnue → HOLD (aucun trade) même sur un job valide.
    function testFuzz_unknownStringYieldsHold(uint256 jobId, uint8 sizeSeed) public {
        // Préparer un job en attente via le happy path.
        _primeHappyPath(jobId);
        _wake(1);

        uint256 capBefore = market.capitalOf(agentId);
        uint256 posBefore = market.positionOf(agentId);

        // Chaîne arbitraire non reconnue (ni BUY ni SELL).
        string memory garbage = string(abi.encodePacked("xyz", sizeSeed));
        _deliver(jobId, garbage);

        // HOLD → état inchangé (Req 3.4).
        assertEq(market.capitalOf(agentId), capBefore, "capital inchange (HOLD)");
        assertEq(market.positionOf(agentId), posBefore, "position inchangee (HOLD)");
    }
}
