// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILeaderboard, ISimpleMarket} from "./interfaces/IArena.sol";

/// @title Leaderboard
/// @notice Calcule et expose le score de performance et le classement des agents
///         de la Ritual Trading Arena (Req 7).
///
/// @dev Score mark-to-market d'un agent (Req 7.1, Property 14) :
///
///          score = capital + (position × dernierPrix) / 1e18
///
///      où `capital` et `position` sont lus depuis le SimpleMarket (source de
///      vérité comptable) et `dernierPrix` est le prix courant du marché.
///
///      `updateScore` est appelé par le SimpleMarket dans la MÊME transaction
///      qu'un trade (Req 7.2). Le classement `ranking()` trie par score
///      décroissant, départage les égalités par agentId croissant, et retourne
///      une liste vide sans erreur si aucun agent n'existe (Req 7.4, 7.5,
///      Property 15). `scoreOf` revert pour un agent inexistant (Req 7.7).
contract Leaderboard is ILeaderboard {
    uint256 internal constant WAD = 1e18;

    // ── Erreurs ──
    error Unauthorized();
    error AgentNotFound();
    error AlreadyRegistered();
    error InvalidAddress();

    // ── État ──
    address public owner;

    /// @notice Marché source des capital/position/prix.
    ISimpleMarket public market;

    /// @notice Adresse autorisée à appeler updateScore (le SimpleMarket).
    address public scoreUpdater;

    /// @notice Adresse autorisée à enregistrer des agents (l'AgentFactory).
    address public registrar;

    mapping(uint256 => uint256) private _score; // dernier score calculé
    mapping(uint256 => bool) private _exists; // agent connu du leaderboard
    uint256[] private _agentIds; // liste des agentIds enregistrés

    // ── Événements ──
    event ScoreUpdated(uint256 indexed agentId, uint256 score);
    event AgentTracked(uint256 indexed agentId);
    event MarketSet(address indexed market);
    event ScoreUpdaterSet(address indexed updater);
    event RegistrarSet(address indexed registrar);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Câblage
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Définit le marché source (capital/position/prix).
    function setMarket(address market_) external onlyOwner {
        if (market_ == address(0)) revert InvalidAddress();
        market = ISimpleMarket(market_);
        emit MarketSet(market_);
    }

    /// @notice Définit l'adresse autorisée à appeler updateScore (le SimpleMarket).
    function setScoreUpdater(address updater) external onlyOwner {
        if (updater == address(0)) revert InvalidAddress();
        scoreUpdater = updater;
        emit ScoreUpdaterSet(updater);
    }

    /// @notice Définit l'adresse autorisée à enregistrer des agents (l'AgentFactory).
    function setRegistrar(address registrar_) external onlyOwner {
        if (registrar_ == address(0)) revert InvalidAddress();
        registrar = registrar_;
        emit RegistrarSet(registrar_);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Suivi des agents
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Enregistre un agent dans le leaderboard (appelé par la fabrique au moment
    ///         de la création) avec un score initial calculé. Exposé immédiatement
    ///         dans le classement même à score nul (Req 7.3, contexte).
    function trackAgent(uint256 agentId) external {
        // Autorisé à l'owner, au registrar (fabrique) ou au score-updater.
        if (msg.sender != owner && msg.sender != registrar && msg.sender != scoreUpdater) {
            revert Unauthorized();
        }
        if (_exists[agentId]) revert AlreadyRegistered();
        _exists[agentId] = true;
        _agentIds.push(agentId);
        _score[agentId] = _computeScore(agentId);
        emit AgentTracked(agentId);
        emit ScoreUpdated(agentId, _score[agentId]);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Scoring
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc ILeaderboard
    /// @dev Appelé par le SimpleMarket dans la même transaction qu'un trade (Req 7.2).
    function updateScore(uint256 agentId) external override {
        if (msg.sender != scoreUpdater && msg.sender != owner) revert Unauthorized();
        // Auto-suivi si l'agent n'était pas encore connu (robustesse).
        if (!_exists[agentId]) {
            _exists[agentId] = true;
            _agentIds.push(agentId);
            emit AgentTracked(agentId);
        }
        uint256 s = _computeScore(agentId);
        _score[agentId] = s;
        emit ScoreUpdated(agentId, s);
    }

    /// @inheritdoc ILeaderboard
    function scoreOf(uint256 agentId) external view override returns (uint256) {
        if (!_exists[agentId]) revert AgentNotFound(); // Req 7.7
        return _score[agentId]; // Req 7.6
    }

    /// @inheritdoc ILeaderboard
    /// @dev Tri par score décroissant ; égalités départagées par agentId croissant
    ///      (Req 7.4). Liste vide sans erreur si aucun agent (Req 7.5).
    function ranking()
        external
        view
        override
        returns (uint256[] memory agentIds, uint256[] memory scores)
    {
        uint256 n = _agentIds.length;
        agentIds = new uint256[](n);
        scores = new uint256[](n);
        if (n == 0) return (agentIds, scores); // Req 7.5

        // Copie locale.
        for (uint256 i = 0; i < n; i++) {
            agentIds[i] = _agentIds[i];
            scores[i] = _score[_agentIds[i]];
        }

        // Tri par insertion (n ≤ 5 agents de démo, coût négligeable).
        // Ordre : score décroissant ; à score égal, agentId croissant (Req 7.4).
        for (uint256 i = 1; i < n; i++) {
            uint256 keyId = agentIds[i];
            uint256 keyScore = scores[i];
            uint256 j = i;
            while (j > 0 && _isBefore(keyScore, keyId, scores[j - 1], agentIds[j - 1])) {
                agentIds[j] = agentIds[j - 1];
                scores[j] = scores[j - 1];
                j--;
            }
            agentIds[j] = keyId;
            scores[j] = keyScore;
        }
    }

    /// @notice Nombre d'agents suivis.
    function agentCount() external view returns (uint256) {
        return _agentIds.length;
    }

    /// @notice Indique si un agent est suivi.
    function exists(uint256 agentId) external view returns (bool) {
        return _exists[agentId];
    }

    // ─────────────────────────────────────────────────────────────────────
    // Interne
    // ─────────────────────────────────────────────────────────────────────

    /// @dev score = capital + position × dernierPrix / 1e18 (Req 7.1).
    function _computeScore(uint256 agentId) internal view returns (uint256) {
        if (address(market) == address(0)) return 0;
        uint256 capital = market.capitalOf(agentId);
        uint256 position = market.positionOf(agentId);
        uint256 price = market.currentPrice();
        return capital + (position * price) / WAD;
    }

    /// @dev Vrai si (scoreA, idA) doit précéder (scoreB, idB) :
    ///      score plus grand d'abord ; à score égal, agentId plus petit d'abord.
    function _isBefore(uint256 scoreA, uint256 idA, uint256 scoreB, uint256 idB)
        internal
        pure
        returns (bool)
    {
        if (scoreA != scoreB) return scoreA > scoreB;
        return idA < idB;
    }
}
