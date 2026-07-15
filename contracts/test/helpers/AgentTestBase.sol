// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentFactory} from "../../src/AgentFactory.sol";
import {AgentDeployer} from "../../src/AgentDeployer.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {TradingAgent} from "../../src/TradingAgent.sol";
import {AgentRecord} from "../../src/interfaces/IArena.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../../src/RitualAddresses.sol";
import {RitualLLM} from "../../src/RitualLLM.sol";
import {RitualMocks} from "./RitualMocks.sol";

/// @title AgentTestBase
/// @notice Base commune : déploie marché + leaderboard + factory, crée un agent,
///         et fournit des helpers pour piloter le cycle 2 phases avec les
///         contrats système Ritual mockés.
contract AgentTestBase is Test {
    SimpleMarket internal market;
    Leaderboard internal lb;
    AgentFactory internal factory;

    TradingAgent internal agent;
    uint256 internal agentId;
    address internal agentAddr;
    address internal walletAddr;

    address internal agentOwner = address(0xA11CE);
    address internal tee = address(0x7EE);

    function _deployArena() internal {
        lb = new Leaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        AgentDeployer deployer = new AgentDeployer();
        factory = new AgentFactory(address(market), address(lb), address(deployer));
        market.setFactory(address(factory));
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(market));
        lb.setRegistrar(address(factory));
    }

    function _createAgent(Strategy s, uint256 capital) internal {
        vm.prank(agentOwner);
        (agentId, agentAddr) = factory.createAgent(s, capital);
        agent = TradingAgent(payable(agentAddr));
        AgentRecord memory rec = factory.getAgent(agentId);
        walletAddr = rec.wallet;
    }

    /// @dev Configure les mocks système pour un commitment réussi.
    function _primeHappyPath(uint256 jobId) internal {
        RitualMocks.mockTeeRegistryWithExecutor(tee);
        RitualMocks.mockWalletBalance(100e18); // capital pour fees suffisant
        RitualMocks.mockNoPendingJob(false);
        RitualMocks.mockLLMResponse(_wrappedLLM("HOLD"));
        // Verrou de dépôt largement au-delà de block + ttl.
        vm.prank(agentOwner);
        agent.recordDepositLock(block.number + 10_000);
    }

    /// @dev Comme `_primeHappyPath` mais impose une décision LLM précise, décodée
    ///      EN-TX par `_wake` (modèle short-running async) : "BUY" / "SELL" / "HOLD".
    function _primeHappyPathWith(uint256 jobId, string memory decision) internal {
        _primeHappyPath(jobId);
        RitualMocks.mockLLMResponse(_wrappedLLM(decision));
    }

    /// @dev Déclenche Phase 0+1 en se faisant passer pour le Scheduler.
    function _wake(uint256 executionIndex) internal {
        vm.prank(RitualAddresses.SCHEDULER);
        agent.autoCycle(executionIndex, 0);
    }

    /// @dev Déclenche Phase 2 en se faisant passer pour AsyncDelivery, avec une
    ///      réponse LLM correctement encodée (enveloppe officielle) contenant la décision.
    function _deliver(uint256 jobId, string memory decision) internal {
        bytes memory result = _buildLLMResponse(decision, false);
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onLLMResult(0, jobId, result);
    }

    function _deliverRaw(uint256 jobId, bytes memory result) internal {
        vm.prank(RitualAddresses.ASYNC_DELIVERY);
        agent.onLLMResult(0, jobId, result);
    }

    /// @dev Construit une enveloppe de réponse LLM conforme à l'ABI officielle,
    ///      dont le contenu du premier choix est `content`.
    function _buildLLMResponse(string memory content, bool hasError)
        internal
        pure
        returns (bytes memory)
    {
        return _buildLLMResponseWithError(content, hasError, "");
    }

    function _buildLLMResponseWithError(
        string memory content,
        bool hasError,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        // messageData : (role, content, refusal, toolCallsCount, toolCallsData[])
        bytes memory messageData = abi.encode(
            "assistant", content, "", uint256(0), new bytes[](0)
        );
        // choice : (index, finishReason, messageData)
        bytes memory choice0 = abi.encode(uint256(0), "stop", messageData);
        bytes[] memory choices = new bytes[](1);
        choices[0] = choice0;
        // usageData : (prompt, completion, total)
        bytes memory usageData = abi.encode(uint256(10), uint256(5), uint256(15));
        // completionData : (id, object, created, model, sysFp, serviceTier, choicesCount, choicesData, usageData)
        bytes memory completionData = abi.encode(
            "id-1",
            "chat.completion",
            uint256(1),
            "zai-org/GLM-4.7-FP8",
            "fp",
            "auto",
            uint256(1),
            choices,
            usageData
        );
        // enveloppe : (hasError, completionData, modelMetadata, errorMessage, updatedConvo)
        RitualLLM.StorageRef memory convo = RitualLLM.StorageRef("", "", "");
        return abi.encode(hasError, completionData, bytes(""), errorMessage, convo);
    }

    /// @dev Enveloppe la réponse LLM dans le wrapper async short-running
    ///      `abi.encode(bytes simmedInput, bytes actualOutput)`, tel que le précompile 0x0802
    ///      le renvoie réellement (le contrat le déballe avant décodage).
    function _wrappedLLM(string memory content) internal pure returns (bytes memory) {
        return abi.encode(bytes(""), _buildLLMResponse(content, false));
    }

    function _wrappedLLMError(string memory errorMessage) internal pure returns (bytes memory) {
        return abi.encode(
            bytes(""), _buildLLMResponseWithError("", true, errorMessage)
        );
    }
}
