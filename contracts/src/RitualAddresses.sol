// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RitualAddresses
/// @notice Source unique de vérité pour les adresses système et precompiles du
///         Ritual Chain Testnet (Chain ID 1979), ainsi que les constantes du
///         Scheduler. Aucune adresse ne doit être codée en dur ailleurs dans le
///         code applicatif (Req 10.6) — toujours référencer cette bibliothèque.
/// @dev Toutes les adresses ci-dessous sont VÉRIFIÉES depuis la documentation
///      officielle Ritual et le repo ritual-dapp-skills. Ne pas inventer ni
///      substituer d'adresses (Req 10.5, 10.6).
library RitualAddresses {
    // ─────────────────────────────────────────────────────────────────────
    // Contrats système Ritual
    // ─────────────────────────────────────────────────────────────────────

    /// @notice RitualWallet — dépôts et verrouillage de fonds pour appels async/planifiés.
    address internal constant RITUAL_WALLET =
        0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948;

    /// @notice Scheduler — planification de rappels périodiques. Seuls des contrats
    ///         peuvent l'appeler ; il rappelle msg.sender.
    address internal constant SCHEDULER =
        0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;

    /// @notice TEEServiceRegistry — découverte des exécuteurs TEE par capacité.
    address internal constant TEE_REGISTRY =
        0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F;

    /// @notice AsyncJobTracker — suivi des jobs async ; un seul job direct en attente
    ///         par adresse expéditrice.
    address internal constant ASYNC_TRACKER =
        0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5;

    /// @notice AsyncDelivery — livre les résultats async via callback. Les callbacks
    ///         doivent vérifier msg.sender == ASYNC_DELIVERY (Req 9.8).
    address internal constant ASYNC_DELIVERY =
        0x5A16214fF555848411544b005f7Ac063742f39F6;

    // ─────────────────────────────────────────────────────────────────────
    // Precompiles Ritual
    // ─────────────────────────────────────────────────────────────────────

    /// @notice LLM Inference precompile (0x0802) — raisonnement / décisions, async 2 phases.
    address internal constant LLM_PRECOMPILE =
        0x0000000000000000000000000000000000000802;

    /// @notice HTTP precompile (0x0801) — récupération de prix de marché externes.
    address internal constant HTTP_PRECOMPILE =
        0x0000000000000000000000000000000000000801;

    /// @notice JQ precompile (0x0803) — extraction déterministe d'une valeur depuis
    ///         une réponse JSON (ex. prix BTC/USD). Synchrone (même tx que le callback).
    address internal constant JQ_PRECOMPILE =
        0x0000000000000000000000000000000000000803;

    /// @notice DKMS precompile (0x081B) — dérivation des clés des agents.
    address internal constant DKMS_PRECOMPILE =
        0x000000000000000000000000000000000000081B;

    // ─────────────────────────────────────────────────────────────────────
    // Constantes du Scheduler (Req 4.4, 4.5, 4.6)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice TTL maximal autorisé par exécution planifiée (en blocs).
    uint32 internal constant MAX_TTL = 500;

    /// @notice Durée de vie maximale d'une planification : frequency × numCalls ≤ 10 000.
    uint32 internal constant MAX_LIFESPAN = 10_000;

    /// @notice Capacité TEE "HTTP_CALL" (0) — exécuteurs pour l'oracle de prix HTTP (0x0801).
    uint8 internal constant CAP_HTTP_CALL = 0;

    /// @notice Capacité TEE "LLM" (1) — exécuteurs d'inférence LLM (0x0802).
    /// @dev Le skill ritual-dapp-llm impose `Capability.LLM = 1` pour sélectionner
    ///      l'exécuteur de l'appel `0x0802`. HTTP (cap 0) et LLM (cap 1) sont des
    ///      ensembles DISTINCTS d'exécuteurs ; ne pas réutiliser un exécuteur HTTP
    ///      pour un appel LLM (sinon l'inférence échoue).
    uint8 internal constant CAP_LLM = 1;
}
