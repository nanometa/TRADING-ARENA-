// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strategy, AgentStatus, OrderType} from "./IRitualSystem.sol";

// ─────────────────────────────────────────────────────────────────────────
// Structures applicatives
// ─────────────────────────────────────────────────────────────────────────

/// @notice Enregistrement d'un agent dans la fabrique (Req 1.4).
struct AgentRecord {
    address agent; // adresse du contrat TradingAgent (= adresse expéditrice)
    address owner; // propriétaire enregistré
    address wallet; // RitualWallet dédié / proxy de dépôt
    Strategy strategy; // stratégie assignée
    AgentStatus status; // ACTIVE / RETIRED
}

// ─────────────────────────────────────────────────────────────────────────
// Interface du marché
// ─────────────────────────────────────────────────────────────────────────

/// @title ISimpleMarket
/// @notice Marché on-chain (AMM produit constant). Source de vérité comptable :
///         détient capital[agentId] et position[agentId] (Req 5).
interface ISimpleMarket {
    /// @notice Émis à chaque trade exécuté (Req 5.7).
    event TradeExecuted(
        uint256 indexed agentId,
        uint8 orderType, // 0 = BUY, 1 = SELL
        uint256 quantity,
        uint256 price,
        uint256 blockNumber
    );

    /// @notice Achat : exige qty>0 et qty*price ≤ capital (Req 5.2). Met à jour
    ///         capital et position atomiquement. Rejette sinon (Req 5.4/5.5).
    function buy(uint256 agentId, uint256 quantity) external returns (uint256 cost);

    /// @notice Vente : exige qty>0 et qty ≤ position (Req 5.3). Met à jour
    ///         capital et position atomiquement. Rejette sinon (Req 5.4/5.5).
    function sell(uint256 agentId, uint256 quantity) external returns (uint256 proceeds);

    /// @notice Prix courant strictement positif d'un actif négociable (Req 5.6).
    function currentPrice() external view returns (uint256);

    /// @notice Capital disponible d'un agent (Req 2.6).
    function capitalOf(uint256 agentId) external view returns (uint256);

    /// @notice Position détenue par un agent.
    function positionOf(uint256 agentId) external view returns (uint256);
}

// ─────────────────────────────────────────────────────────────────────────
// Interface du leaderboard
// ─────────────────────────────────────────────────────────────────────────

/// @title ILeaderboard
/// @notice Scoring mark-to-market et classement (Req 7).
interface ILeaderboard {
    /// @notice Recalcule le score d'un agent : capital + position × dernierPrix.
    ///         Appelé par SimpleMarket dans la même transaction qu'un trade (Req 7.2).
    function updateScore(uint256 agentId) external;

    /// @notice Enregistre/expose un agent dans le leaderboard (appelé par la fabrique
    ///         en tant que registrar, à la création — score nul au départ).
    function trackAgent(uint256 agentId) external;

    /// @notice Score courant d'un agent existant ; revert si inexistant (Req 7.6/7.7).
    function scoreOf(uint256 agentId) external view returns (uint256);

    /// @notice Classement trié par score décroissant ; égalités départagées par
    ///         agentId croissant ; vide si aucun agent (Req 7.4/7.5).
    function ranking()
        external
        view
        returns (uint256[] memory agentIds, uint256[] memory scores);
}

// ─────────────────────────────────────────────────────────────────────────
// Interface de la fabrique d'agents
// ─────────────────────────────────────────────────────────────────────────

/// @title IAgentFactory
/// @notice Création, enregistrement et cycle de vie des agents (Req 1, 2.1, 10.2/10.3).
interface IAgentFactory {
    event AgentCreated(
        uint256 indexed agentId,
        address indexed agent,
        address indexed owner,
        Strategy strategy
    );
    event AgentRetired(uint256 indexed agentId);

    /// @notice Crée un agent avec une stratégie et un capital initial (Req 1.1–1.3, 1.5, 1.6).
    function createAgent(Strategy strategy, uint256 initialCapital)
        external
        returns (uint256 agentId, address agent);

    /// @notice Retire un agent (réservé à l'owner) (Req 1.7–1.9, 9.3, 9.4).
    function retireAgent(uint256 agentId) external;

    /// @notice Enregistrement d'un agent (Req 1.4).
    function getAgent(uint256 agentId) external view returns (AgentRecord memory);

    /// @notice Liste consultable de tous les agents (Req 1.4).
    function listAgents() external view returns (AgentRecord[] memory);

    /// @notice Nombre d'agents actifs.
    function activeAgentCount() external view returns (uint256);

    /// @notice Crée un agent de démonstration (plafonné à 5) (Req 10.2, 10.3).
    function createDemoAgent(Strategy strategy, uint256 initialCapital)
        external
        returns (uint256 agentId);
}

// ─────────────────────────────────────────────────────────────────────────
// Interface de l'agent de trading
// ─────────────────────────────────────────────────────────────────────────

/// @title ITradingAgent
/// @notice Agent autonome : auto-planification, cycle LLM 2 phases, sécurité (Req 2,3,4,6,9).
interface ITradingAgent {
    // ── Activation / planification (Req 4) ──
    function activate(uint32 frequency, uint32 numCalls, uint32 ttl) external;
    function pause() external; // Req 9.3
    function resume() external;
    function emergencyStop() external; // Req 9.5
    function emergencyWithdraw() external; // Req 9.6, 9.7

    // ── Callback du Scheduler (Phase 0) — executionIndex injecté en bytes 4-35 ──
    function autoCycle(uint256 executionIndex, uint256 seriesId) external;

    // ── Callback LLM (Phase 2) — réservé à AsyncDelivery (Req 9.8/9.9) ──
    function onLLMResult(uint256 executionIndex, uint256 jobId, bytes calldata result) external;

    // ── Configuration sécurité (Req 9.1) ──
    function setBudgetLimit(uint256 limit, uint256 windowSeconds) external;

    // ── Lectures (Req 2.6) ──
    function availableCapital() external view returns (uint256);
    function position() external view returns (uint256);
    function strategy() external view returns (Strategy);
}
