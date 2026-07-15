// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ─────────────────────────────────────────────────────────────────────────
// Enums partagés du domaine (Req 1.5, 1.x)
// ─────────────────────────────────────────────────────────────────────────

/// @notice Stratégie de trading d'un agent (Req 1.5).
enum Strategy {
    TREND_FOLLOWING,
    MEAN_REVERSION
}

/// @notice État de cycle de vie d'un agent (Req 1.4, 1.6, 1.7).
enum AgentStatus {
    ACTIVE,
    RETIRED
}

/// @notice Type d'ordre sur le marché (Req 5.7).
enum OrderType {
    BUY,
    SELL
}

/// @notice Décision de trading issue du LLM (Req 3.3).
enum Decision {
    HOLD, // « ne rien faire »
    BUY, // « acheter »
    SELL // « vendre »
}

// ─────────────────────────────────────────────────────────────────────────
// Interfaces des contrats système Ritual
// ─────────────────────────────────────────────────────────────────────────

/// @title IRitualWallet
/// @notice Interface du contrat système RitualWallet (dépôts + verrouillage).
interface IRitualWallet {
    /// @notice Dépose des fonds natifs RITUAL avec une durée de verrouillage (en blocs).
    /// @param lockDuration Nombre de blocs pendant lesquels le dépôt reste verrouillé.
    function deposit(uint256 lockDuration) external payable;

    /// @notice Retire un solde après expiration de son verrou.
    function withdraw(uint256 amount) external;

    /// @notice Solde verrouillé/disponible d'un compte dans le RitualWallet.
    function balanceOf(address account) external view returns (uint256);
}

/// @title IScheduler
/// @notice Interface du contrat système Scheduler. Seuls des contrats peuvent
///         planifier ; le Scheduler rappelle msg.sender. L'index d'exécution est
///         injecté dans les octets 4-35 du calldata du callback (Req 4.7).
interface IScheduler {
    /// @notice Overload complet de planification.
    /// @param data Calldata du callback (1er param après le sélecteur = uint256 executionIndex factice).
    /// @param gas Limite de gaz par exécution.
    /// @param startBlock Bloc de démarrage.
    /// @param numCalls Nombre d'exécutions (numCalls × frequency ≤ MAX_LIFESPAN).
    /// @param frequency Intervalle en blocs entre deux exécutions.
    /// @param ttl Fenêtre de vie d'une exécution (≤ MAX_TTL).
    /// @param maxFeePerGas Plafond EIP-1559.
    /// @param maxPriorityFeePerGas Pourboire EIP-1559.
    /// @param value Valeur native envoyée à chaque exécution.
    /// @param payer Adresse dont le RitualWallet est débité.
    /// @return callId Identifiant de la planification.
    function schedule(
        bytes calldata data,
        uint32 gas,
        uint32 startBlock,
        uint32 numCalls,
        uint32 frequency,
        uint32 ttl,
        uint256 maxFeePerGas,
        uint256 maxPriorityFeePerGas,
        uint256 value,
        address payer
    ) external returns (uint256 callId);

    /// @notice Overload court (auto-remplit startBlock/ttl/fees/value/payer).
    function schedule(
        bytes calldata data,
        uint32 gas,
        uint32 numCalls,
        uint32 frequency
    ) external returns (uint256 callId);

    /// @notice Annule une planification.
    function cancel(uint256 callId) external;

    /// @notice Autorise `schedulerContract` à planifier en utilisant l'appelant
    ///         comme payer (Payer Semantics : le payer/sponsor appelle ceci).
    function approveScheduler(address schedulerContract) external;

    /// @notice État courant d'une planification (0=SCHEDULED,1=EXECUTING,2=COMPLETED,3=CANCELLED,4=EXPIRED).
    function getCallState(uint256 callId) external view returns (uint8);
}

/// @title IAsyncJobTracker
/// @notice Interface du contrat système AsyncJobTracker. Un seul job async direct
///         en attente par adresse expéditrice (Req 2.1).
interface IAsyncJobTracker {
    /// @notice Indique si l'adresse a déjà un job async direct en attente.
    function hasPendingJobForSender(address sender) external view returns (bool);
}

/// @title ITEEServiceRegistry
/// @notice Interface du registre des exécuteurs TEE. Découverte à l'exécution :
///         ne jamais coder en dur l'adresse d'un exécuteur (Req 3.6, 3.8).
interface ITEEServiceRegistry {
    struct Node {
        address paymentAddress;
        address teeAddress;
        uint8 teeType;
        bytes publicKey;
        string endpoint;
        bytes32 certPubKeyHash;
        uint8 capability;
    }

    struct Service {
        Node node;
        bool isValid;
        bytes32 workloadId;
    }

    /// @notice Liste les services disponibles pour une capacité donnée.
    /// @param capability Capacité recherchée (HTTP_CALL = 0).
    /// @param checkValidity Si vrai, ne retourne que les services valides.
    function getServicesByCapability(uint8 capability, bool checkValidity)
        external
        view
        returns (Service[] memory);
}

/// @title ILLMPrecompile
/// @notice Vue logique du precompile LLM Inference (0x0802). L'appel réel se fait
///         via un `call` bas niveau encodé ; cette interface documente la forme
///         de la Phase 1 (commitment) qui retourne un jobId synchrone (Req 3.2).
interface ILLMPrecompile {
    /// @notice Soumet une requête d'inférence ; retourne un jobId (Phase 1).
    function inference(bytes calldata request) external returns (uint256 jobId);
}
