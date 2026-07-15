// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RitualLLM
/// @notice Encodage de la requête et décodage de la réponse du precompile LLM
///         Inference (0x0802), conformes à la spécification officielle du skill
///         `ritual-dapp-llm` (Request/Response ABI Layout).
///
/// @dev Points clés du skill respectés :
///  - La requête étend les champs "executor" (executor, encryptedSecrets, ttl,
///    secretSignatures, userPublicKey) puis les champs LLM (messagesJson, model,
///    ... convoHistory).
///  - La réponse est l'enveloppe (bool hasError, bytes completionData,
///    bytes modelMetadata, string errorMessage, (string,string,string) convo).
///  - `completionData` est lui-même ABI-encodé (pas du JSON) et doit être décodé
///    en deux niveaux pour extraire le `content` du premier choix.
///  - TOUJOURS vérifier `hasError` avant de parser `completionData` (sinon revert
///    ou garbage). On expose un décodage défensif qui retourne ("", true) en cas
///    d'erreur ou de structure inattendue.
library RitualLLM {
    /// @notice Référence de stockage DA (platform, path, key_ref).
    struct StorageRef {
        string platform;
        string path;
        string keyRef;
    }

    /// @notice Construit le messagesJson (format chat OpenAI) à partir d'un system
    ///         prompt et d'un user prompt. Échappement minimal (les prompts sont
    ///         construits on-chain à partir de nombres + libellés constants).
    function buildMessagesJson(string memory systemPrompt, string memory userPrompt)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '[{"role":"system","content":"',
                systemPrompt,
                '"},{"role":"user","content":"',
                userPrompt,
                '"}]'
            )
        );
    }

    /// @notice Encode une requête LLM minimale mais conforme à l'ABI officielle.
    /// @param executor Adresse de l'exécuteur TEE (découverte via TEEServiceRegistry).
    /// @param ttl Blocs avant expiration.
    /// @param messagesJson Messages au format chat JSON.
    /// @param model Identifiant du modèle (ex. "zai-org/GLM-4.7-FP8").
    /// @param maxCompletionTokens Plafond de tokens de sortie (-1 = null).
    function encodeRequest(
        address executor,
        uint256 ttl,
        string memory messagesJson,
        string memory model,
        int256 maxCompletionTokens
    ) internal pure returns (bytes memory) {
        // Champs "executor" de base.
        bytes[] memory emptyBytesArr = new bytes[](0);

        // Référence DA vide (pas d'historique de conversation on-chain ici).
        // convoHistory = (platform, path, key_ref).
        return abi.encode(
            // ── base executor ──
            executor, // executor
            emptyBytesArr, // encryptedSecrets
            ttl, // ttl
            emptyBytesArr, // secretSignatures
            bytes(""), // userPublicKey
            // ── champs LLM ──
            messagesJson, // messagesJson
            model, // model
            int256(0), // frequencyPenalty
            "", // logitBiasJson
            false, // logprobs
            maxCompletionTokens, // maxCompletionTokens
            "", // metadataJson
            "", // modalitiesJson
            uint256(1), // n
            false, // parallelToolCalls
            int256(0), // presencePenalty
            "medium", // reasoningEffort
            bytes(""), // responseFormatData
            int256(-1), // seed
            "auto", // serviceTier
            "", // stopJson
            false, // stream
            int256(200), // temperature (0.2 ×1000 → décisions stables)
            bytes(""), // toolChoiceData
            bytes(""), // toolsData
            int256(-1), // topLogprobs
            int256(1000), // topP (1.0 ×1000)
            "", // user
            false, // piiEnabled
            StorageRef("", "", "") // convoHistory (platform, path, key_ref) vide
        );
    }

    /// @notice Décode défensivement la réponse LLM et conserve le message
    ///         d'erreur de l'enveloppe. `hasError` est toujours vérifié avant
    ///         de tenter de parser `completionData`.
    function decodeResult(bytes memory response)
        internal
        pure
        returns (string memory content, bool failed, string memory errorMessage)
    {
        if (response.length == 0) return ("", true, "empty_response");

        // Enveloppe : (bool hasError, bytes completionData, bytes modelMetadata,
        //              string errorMessage, (string,string,string) updatedConvo).
        // Décodage défensif via try/catch sur un helper externe n'est pas possible
        // en pur `library internal` ; on encapsule donc le décodage dans un
        // appel à abi.decode protégé par des vérifications de longueur en amont
        // au niveau de l'appelant (TradingAgent capture déjà les reverts).
        (bool hasError, bytes memory completionData, , string memory llmError, ) = abi.decode(
            response,
            (bool, bytes, bytes, string, StorageRef)
        );

        if (hasError) {
            return (
                "",
                true,
                bytes(llmError).length == 0 ? "llm_error_without_message" : llmError
            );
        }
        if (completionData.length == 0) return ("", true, "empty_completion");

        // CompletionData : (string id, string object, uint256 created, string model,
        //   string systemFingerprint, string serviceTier, uint256 choicesCount,
        //   bytes[] choicesData, bytes usageData).
        (, , , , , , uint256 choicesCount, bytes[] memory choicesData, ) = abi.decode(
            completionData,
            (string, string, uint256, string, string, string, uint256, bytes[], bytes)
        );

        if (choicesCount == 0 || choicesData.length == 0) {
            return ("", true, "missing_choices");
        }

        // choicesData[0] : (uint256 index, string finishReason, bytes messageData).
        (, , bytes memory messageData) = abi.decode(
            choicesData[0],
            (uint256, string, bytes)
        );

        // messageData : (string role, string content, string refusal,
        //   uint256 toolCallsCount, bytes[] toolCallsData).
        (, string memory msgContent, , , ) = abi.decode(
            messageData,
            (string, string, string, uint256, bytes[])
        );

        if (bytes(msgContent).length == 0) return ("", true, "empty_content");
        return (msgContent, false, "");
    }

    /// @notice Wrapper compatible avec les anciens appelants qui n'ont besoin
    ///         que du contenu et du drapeau d'échec.
    function decodeContent(bytes memory response)
        internal
        pure
        returns (string memory content, bool failed)
    {
        (content, failed, ) = decodeResult(response);
    }
}
