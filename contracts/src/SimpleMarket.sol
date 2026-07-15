// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISimpleMarket, ILeaderboard} from "./interfaces/IArena.sol";

/// @title SimpleMarket
/// @notice Marché on-chain pour la Ritual Trading Arena.
///
/// @dev Modèle : AMM à produit constant sur un actif unique négociable contre du
///      capital (RITUAL, 18 décimales). Le prix courant est dérivé des réserves :
///
///          price = reserveQuote * 1e18 / reserveBase      (18 décimales)
///
///      Il est strictement positif tant que les deux réserves restent > 0
///      (Req 5.1, 5.6, Property 11). Chaque trade s'exécute au prix courant
///      capturé AVANT la mutation, ce qui rend la comptabilité déterministe :
///
///          achat  : cost     = qty * price / 1e18 ; capital -= cost ; position += qty
///          vente  : proceeds = qty * price / 1e18 ; capital += proceeds ; position -= qty
///
///      Capital et position sont mis à jour ATOMIQUEMENT dans la même transaction
///      (Req 5.2, 5.3, Property 9). Tout ordre invalide ou non couvert est rejeté
///      en totalité, sans exécution partielle ni mutation d'état (Req 5.4, 5.5,
///      Property 10). Le marché est la SOURCE DE VÉRITÉ comptable : il détient
///      `capital[agentId]` et `position[agentId]`, émet `TradeExecuted` (Req 5.7)
///      et déclenche `Leaderboard.updateScore` dans la même transaction (Req 7.2).
contract SimpleMarket is ISimpleMarket {
    // ─────────────────────────────────────────────────────────────────────
    // Constantes
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Échelle des décimales fixes (18) partagée par capital, position et prix.
    uint256 internal constant WAD = 1e18;

    // ─────────────────────────────────────────────────────────────────────
    // Erreurs (custom errors — moins de gaz, cause explicite)
    // ─────────────────────────────────────────────────────────────────────

    error Unauthorized();
    error InvalidOrder(); // qty == 0 ou actif/agent non négociable (Req 5.5)
    error InsufficientFundsOrPosition(); // couverture capital/position absente (Req 5.4)
    error AlreadyRegistered();
    error NotRegistered();
    error InvalidReserves();
    error Reentrancy();

    // ─────────────────────────────────────────────────────────────────────
    // État
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Propriétaire administratif (déploiement / câblage).
    address public owner;

    /// @notice Fabrique autorisée à enregistrer des agents.
    address public factory;

    /// @notice Leaderboard mis à jour à chaque trade (Req 7.2).
    ILeaderboard public leaderboard;

    /// @notice Réserves de l'AMM (produit constant). price = reserveQuote/reserveBase.
    uint256 public reserveBase; // unités de l'actif négociable
    uint256 public reserveQuote; // RITUAL

    /// @notice Comptabilité par agent (source de vérité).
    mapping(uint256 => uint256) private _capital; // RITUAL disponible
    mapping(uint256 => uint256) private _position; // unités d'actif détenues

    /// @notice Contrôleur autorisé à trader pour un agentId (= contrat TradingAgent).
    mapping(uint256 => address) public agentController;
    mapping(uint256 => bool) public registered;

    uint256 private _lock = 1;

    // ─────────────────────────────────────────────────────────────────────
    // Événements administratifs
    // ─────────────────────────────────────────────────────────────────────

    event AgentRegistered(uint256 indexed agentId, address indexed controller, uint256 initialCapital);
    event FactorySet(address indexed factory);
    event LeaderboardSet(address indexed leaderboard);

    // ─────────────────────────────────────────────────────────────────────
    // Modificateurs
    // ─────────────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyFactory() {
        if (msg.sender != factory) revert Unauthorized();
        _;
    }

    /// @dev Verrou de réentrance simple : le seul appel externe est vers le
    ///      leaderboard (de confiance), mais on protège par principe.
    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Construction & câblage
    // ─────────────────────────────────────────────────────────────────────

    /// @param leaderboard_ Adresse du Leaderboard (déployé en amont).
    /// @param reserveBase0 Réserve initiale d'actif (> 0).
    /// @param reserveQuote0 Réserve initiale de quote/RITUAL (> 0).
    constructor(address leaderboard_, uint256 reserveBase0, uint256 reserveQuote0) {
        if (reserveBase0 == 0 || reserveQuote0 == 0) revert InvalidReserves();
        owner = msg.sender;
        leaderboard = ILeaderboard(leaderboard_);
        reserveBase = reserveBase0;
        reserveQuote = reserveQuote0;
        emit LeaderboardSet(leaderboard_);
    }

    /// @notice Définit la fabrique autorisée (une seule fois).
    function setFactory(address factory_) external onlyOwner {
        if (factory != address(0)) revert AlreadyRegistered();
        factory = factory_;
        emit FactorySet(factory_);
    }

    /// @notice Met à jour l'adresse du leaderboard (câblage post-déploiement).
    function setLeaderboard(address leaderboard_) external onlyOwner {
        leaderboard = ILeaderboard(leaderboard_);
        emit LeaderboardSet(leaderboard_);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Enregistrement des agents (appelé par la fabrique)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Enregistre un agent avec son capital initial et son contrôleur autorisé.
    /// @dev Appelé par l'AgentFactory au moment de la création (Req 1.1, 2.1).
    function registerAgent(uint256 agentId, address controller, uint256 initialCapital)
        external
        onlyFactory
    {
        if (registered[agentId]) revert AlreadyRegistered();
        if (controller == address(0)) revert InvalidOrder();
        registered[agentId] = true;
        agentController[agentId] = controller;
        _capital[agentId] = initialCapital;
        emit AgentRegistered(agentId, controller, initialCapital);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Trading
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc ISimpleMarket
    function buy(uint256 agentId, uint256 quantity)
        external
        override
        nonReentrant
        returns (uint256 cost)
    {
        _requireController(agentId);
        if (quantity == 0) revert InvalidOrder();

        uint256 price = currentPrice();
        cost = (quantity * price) / WAD;

        // Couverture stricte (Req 5.2). Garde-fou de liquidité : conserver reserveBase > 0.
        if (cost > _capital[agentId]) revert InsufficientFundsOrPosition();
        if (quantity >= reserveBase) revert InsufficientFundsOrPosition();

        // Mutation atomique (Req 5.2, Property 9).
        _capital[agentId] -= cost;
        _position[agentId] += quantity;

        // Déplacement de prix réaliste (produit constant) : l'achat d'actif
        // réduit la réserve d'actif et augmente la réserve de quote.
        reserveBase -= quantity;
        reserveQuote += cost;

        emit TradeExecuted(agentId, uint8(0), quantity, price, block.number);
        leaderboard.updateScore(agentId);
    }

    /// @inheritdoc ISimpleMarket
    function sell(uint256 agentId, uint256 quantity)
        external
        override
        nonReentrant
        returns (uint256 proceeds)
    {
        _requireController(agentId);
        if (quantity == 0) revert InvalidOrder();

        // Couverture stricte de position (Req 5.3).
        if (quantity > _position[agentId]) revert InsufficientFundsOrPosition();

        uint256 price = currentPrice();
        proceeds = (quantity * price) / WAD;

        // Garde-fou de liquidité : conserver reserveQuote > 0 (prix strictement positif).
        if (proceeds >= reserveQuote) revert InsufficientFundsOrPosition();

        // Mutation atomique (Req 5.3, Property 9).
        _capital[agentId] += proceeds;
        _position[agentId] -= quantity;

        // Déplacement de prix : la vente d'actif augmente la réserve d'actif
        // et réduit la réserve de quote.
        reserveBase += quantity;
        reserveQuote -= proceeds;

        emit TradeExecuted(agentId, uint8(1), quantity, price, block.number);
        leaderboard.updateScore(agentId);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Lectures
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc ISimpleMarket
    /// @dev Strictement positif tant que les réserves restent > 0 (Property 11).
    function currentPrice() public view override returns (uint256) {
        return (reserveQuote * WAD) / reserveBase;
    }

    /// @inheritdoc ISimpleMarket
    function capitalOf(uint256 agentId) external view override returns (uint256) {
        return _capital[agentId];
    }

    /// @inheritdoc ISimpleMarket
    function positionOf(uint256 agentId) external view override returns (uint256) {
        return _position[agentId];
    }

    // ─────────────────────────────────────────────────────────────────────
    // Interne
    // ─────────────────────────────────────────────────────────────────────

    function _requireController(uint256 agentId) internal view {
        if (!registered[agentId]) revert NotRegistered();
        if (msg.sender != agentController[agentId]) revert Unauthorized();
    }
}
