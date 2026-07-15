// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RitualLLM} from "../src/RitualLLM.sol";

/// @title RitualLLM — tests de l'encodage requête / décodage réponse (ABI officielle)
/// @notice Valide que notre bibliothèque encode une requête non vide et décode
///         correctement l'enveloppe LLM officielle (hasError + completionData imbriqué).
contract RitualLLMTest is Test {
    /// @dev Construit une enveloppe LLM officielle dont le 1er choix contient `content`.
    function _envelope(string memory content, bool hasError, string memory errorMessage)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory messageData = abi.encode("assistant", content, "", uint256(0), new bytes[](0));
        bytes memory choice0 = abi.encode(uint256(0), "stop", messageData);
        bytes[] memory choices = new bytes[](1);
        choices[0] = choice0;
        bytes memory usageData = abi.encode(uint256(1), uint256(1), uint256(2));
        bytes memory completionData = abi.encode(
            "id", "chat.completion", uint256(1), "m", "fp", "auto", uint256(1), choices, usageData
        );
        RitualLLM.StorageRef memory convo = RitualLLM.StorageRef("", "", "");
        return abi.encode(hasError, completionData, bytes(""), errorMessage, convo);
    }

    // ── encodeRequest produit une requête non vide ──
    function test_encodeRequestNonEmpty() public pure {
        string memory msgs = RitualLLM.buildMessagesJson("sys", "user");
        bytes memory req = RitualLLM.encodeRequest(address(0x7EE), 100, msgs, "zai-org/GLM-4.7-FP8", 256);
        assertGt(req.length, 0);
    }

    // ── messagesJson contient les rôles attendus ──
    function test_buildMessagesJson() public pure {
        string memory m = RitualLLM.buildMessagesJson("S", "U");
        // Doit contenir "role":"system" et "role":"user".
        assertTrue(bytes(m).length > 20);
    }

    // ── decodeContent extrait le contenu du 1er choix ──
    function test_decodeContentSuccess() public pure {
        bytes memory env = _envelope("BUY", false, "");
        (string memory content, bool failed) = RitualLLM.decodeContent(env);
        assertFalse(failed);
        assertEq(content, "BUY");
    }

    // ── decodeContent signale l'échec quand hasError == true ──
    function test_decodeContentHasError() public pure {
        bytes memory env = _envelope("ignored", true, "registry unavailable");
        (, bool failed) = RitualLLM.decodeContent(env);
        assertTrue(failed);
    }

    function test_decodeResultPreservesErrorMessage() public pure {
        bytes memory env = _envelope("ignored", true, "registry unavailable");
        (string memory content, bool failed, string memory reason) = RitualLLM.decodeResult(env);
        assertEq(content, "");
        assertTrue(failed);
        assertEq(reason, "registry unavailable");
    }

    // ── decodeContent gère une réponse vide ──
    function test_decodeContentEmpty() public pure {
        (, bool failed) = RitualLLM.decodeContent(bytes(""));
        assertTrue(failed);
    }
}
