// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentTestBase} from "./helpers/AgentTestBase.sol";
import {TradingAgent} from "../src/TradingAgent.sol";
import {Strategy} from "../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../src/RitualAddresses.sol";
import {RitualMocks} from "./helpers/RitualMocks.sol";

/// @title PriceOracle — tests de l'oracle de prix externe (HTTP precompile 0x0801)
/// @notice Couvre la requête HTTP, le callback autorisé, la mise en cache du prix
///         externe et le fallback sur le prix AMM quand le prix externe est périmé.
contract PriceOracleTest is AgentTestBase {
    function setUp() public {
        _deployArena();
        _createAgent(Strategy.TREND_FOLLOWING, 100_000e18);
    }

    // ── requestPrice appelle le HTTP precompile via un exécuteur découvert ──
    function test_requestPriceCallsHttpPrecompile() public {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        // Le HTTP precompile renvoie le wrapper async (simmedInput, actualOutput=réponse HTTP).
        // requestPrice lit désormais le prix EN-TX (modèle ritual-ta-oracle), pas via onPriceResult.
        string memory json = '{"bitcoin":{"usd":67000}}';
        bytes memory httpResp = RitualMocks.encodeHttpResponse(200, json);
        vm.mockCall(RitualAddresses.HTTP_PRECOMPILE, bytes(""), abi.encode(bytes(""), httpResp));
        RitualMocks.mockJqReturns(67_000e18);

        vm.prank(agentOwner);
        agent.requestPrice(); // ne doit pas revert ; lit et met en cache le prix en-tx

        assertEq(agent.externalPrice(), 67_000e18, "prix BTC lu et mis en cache en-tx");
        assertEq(agent.externalPriceBlock(), uint64(block.number), "bloc de fraicheur");
    }

    // ── requestPrice sans exécuteur → pas de revert, événement TeeUnavailable ──
    function test_requestPriceNoExecutor() public {
        RitualMocks.mockTeeRegistryEmpty();
        vm.prank(agentOwner);
        agent.requestPrice(); // abandon propre
        assertEq(agent.externalPrice(), 0);
    }

    // ── onPriceResult réservé à AsyncDelivery ──
    function test_onPriceResultOnlyAsyncDelivery() public {
        bytes memory result = abi.encode(uint256(2000e18));
        vm.prank(address(0xDEAD));
        vm.expectRevert(TradingAgent.BadCallbackSender.selector);
        agent.onPriceResult(0, bytes32(0), result);
    }

    // ── onPriceResult met en cache le prix externe ──
    function test_onPriceResultCachesPrice() public {
        bytes memory result = abi.encode(uint256(2000e18));
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onPriceResult(0, bytes32(0), result);
        assertEq(agent.externalPrice(), 2000e18);
        assertEq(agent.externalPriceBlock(), uint64(block.number));
    }

    // ── Décodage invalide → prix externe inchangé (fallback AMM) ──
    function test_onPriceResultBadDecodeKeepsFallback() public {
        bytes memory bad = hex"01"; // trop court pour un uint256
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onPriceResult(0, bytes32(0), bad);
        assertEq(agent.externalPrice(), 0); // non mis à jour
    }

    // ── onPriceResult avec une vraie réponse HTTP JSON + JQ (BTC/USD live) ──
    function test_onPriceResultHttpJsonViaJq() public {
        // Réponse réaliste de CoinGecko BTC/USD.
        string memory json = '{"bitcoin":{"usd":67000}}';
        bytes memory httpResp = RitualMocks.encodeHttpResponse(200, json);

        // Le precompile JQ extrait 67000 * 1e18 (filtre WAD).
        RitualMocks.mockJqReturns(67_000e18);

        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onPriceResult(0, bytes32(0), httpResp);

        assertEq(agent.externalPrice(), 67_000e18);
        assertEq(agent.externalPriceBlock(), uint64(block.number));
    }

    // ── Réponse HTTP non-2xx → prix inchangé (fallback AMM) ──
    function test_onPriceResultHttpErrorKeepsFallback() public {
        bytes memory httpResp = RitualMocks.encodeHttpResponse(429, "rate limited");
        RitualMocks.mockJqReturns(67_000e18); // ne doit pas être utilisé
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onPriceResult(0, bytes32(0), httpResp);
        assertEq(agent.externalPrice(), 0); // non mis à jour
    }

    // ── setPricePair owner-only + bascule de paire ──
    function test_setPricePair() public {
        vm.prank(agentOwner);
        agent.setPricePair(
            "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd",
            "(.ethereum.usd * 1000000000000000000) | floor",
            "ETH/USD",
            300
        );
        assertEq(agent.priceSymbol(), "ETH/USD");
        assertEq(agent.priceFreshnessBlocks(), 300);
    }

    // ── Config owner-only ──
    function test_setPriceConfigOwnerOnly() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(TradingAgent.Unauthorized.selector);
        agent.setPriceConfig("https://x", 100);

        vm.prank(agentOwner);
        agent.setPriceConfig("https://api.example/price", 300);
        assertEq(agent.priceFreshnessBlocks(), 300);
    }

    // ── autoCycle lance directement le LLM puis le trade dès l'index 0 ──
    function test_autoCycleCallsLlmAndTradesImmediately() public {
        _primeHappyPathWith(1, "BUY");
        uint256 posBefore = market.positionOf(agentId);
        vm.prank(RitualAddresses.SCHEDULER);
        agent.autoCycle(0, 0);
        assertGt(market.positionOf(agentId), posBefore, "premier cycle execute le trade BUY");
    }

    // ── FIX AUTOPILOTE (preuve décisive) : l'ANALYSE tourne + trade MÊME quand un
    //    job "traîne" en attente côté tracker — exactement le scénario qui SAUTAIT en
    //    live (PendingJobSkipped). Le garde `hasPendingJobForSender` ayant été retiré,
    //    l'analyse ne doit plus jamais être sautée pour cette raison. ──
    function test_autoCycleAnalyzeRunsDespitePendingJob() public {
        _primeHappyPathWith(1, "BUY");
        RitualMocks.mockNoPendingJob(true); // override : un job est signalé "pending"
        uint256 posBefore = market.positionOf(agentId);
        vm.prank(RitualAddresses.SCHEDULER);
        agent.autoCycle(0, 0);
        assertGt(
            market.positionOf(agentId),
            posBefore,
            "ANALYSE trade MALGRE un job pending (garde retire)"
        );
    }

    // ── setDaCheckpoint owner-only + stockage ──
    function test_setDaCheckpoint() public {
        vm.prank(agentOwner);
        agent.setDaCheckpoint("hf", "org/repo/MEMORY.md", 4096);
        assertEq(agent.daPlatform(), "hf");
        assertEq(agent.daPath(), "org/repo/MEMORY.md");
        assertEq(agent.onchainMemoryThreshold(), 4096);
    }
}
