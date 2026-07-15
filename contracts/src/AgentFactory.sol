// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentFactory, AgentRecord, ISimpleMarket, ILeaderboard} from "./interfaces/IArena.sol";
import {Strategy, AgentStatus} from "./interfaces/IRitualSystem.sol";
import {TradingAgent} from "./TradingAgent.sol";
import {AgentDeployer} from "./AgentDeployer.sol";

/// @title AgentFactory
/// @notice Crée, enregistre et gère le cycle de vie des Trading_Agent (Req 1, 2.1,
///         10.2, 10.3).
///
/// @dev Pour chaque création, la fabrique déploie DEUX contrats distincts :
///      un `TradingAgent` (dont l'adresse sert d'expéditeur) et un `AgentWallet`
///      dédié. Les adresses étant issues de `CREATE`, elles sont uniques et non
///      partagées entre agents (Property 1). La fabrique enregistre ensuite
///      l'agent auprès du SimpleMarket (capital initial + contrôleur) et du
///      Leaderboard (exposition immédiate, score nul au départ).
contract AgentFactory is IAgentFactory {
    /// @notice Version du bytecode attendu par le frontend. Ce garde-fou empêche
    ///         de financer un agent créé par une ancienne Factory immuable.
    uint256 public constant IMPLEMENTATION_VERSION = 2;

    // ── Bornes de capital (Req 1.1, 1.6) ──
    uint256 internal constant MIN_CAPITAL = 0.01e18;
    uint256 internal constant MAX_CAPITAL = 999_999_999.99e18;

    /// @notice Plafond d'agents de démonstration (Req 10.3).
    uint256 internal constant MAX_DEMO_AGENTS = 5;

    // ── Erreurs ──
    error Unauthorized();
    error UnsupportedStrategy();
    error InvalidInitialCapital();
    error AgentNotFound();
    error AlreadyRetired();
    error DemoLimitReached();

    // ── État ──
    address public owner;
    ISimpleMarket public market;
    ILeaderboard public leaderboard;
    AgentDeployer public deployer;

    uint256 public nextAgentId;
    uint256 public demoAgentCount;

    mapping(uint256 => AgentRecord) private _agents;
    uint256[] private _agentIds;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @param market_ SimpleMarket déployé (la fabrique doit en être la factory autorisée).
    /// @param leaderboard_ Leaderboard déployé (la fabrique doit en être le registrar).
    /// @param deployer_ AgentDeployer déployé (porte le bytecode des enfants).
    constructor(address market_, address leaderboard_, address deployer_) {
        owner = msg.sender;
        market = ISimpleMarket(market_);
        leaderboard = ILeaderboard(leaderboard_);
        deployer = AgentDeployer(deployer_);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Création
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc IAgentFactory
    function createAgent(Strategy strategy, uint256 initialCapital)
        external
        override
        returns (uint256 agentId, address agent)
    {
        return _createAgent(strategy, initialCapital, msg.sender, false);
    }

    /// @inheritdoc IAgentFactory
    /// @dev Plafonné à 5 agents de démonstration (Req 10.3).
    function createDemoAgent(Strategy strategy, uint256 initialCapital)
        external
        override
        returns (uint256 agentId)
    {
        if (demoAgentCount >= MAX_DEMO_AGENTS) revert DemoLimitReached();
        demoAgentCount++;
        (agentId, ) = _createAgent(strategy, initialCapital, msg.sender, true);
    }

    function _createAgent(
        Strategy strategy,
        uint256 initialCapital,
        address agentOwner,
        bool /* isDemo */
    ) internal returns (uint256 agentId, address agent) {
        // Validation de la stratégie (Req 1.5). L'enum garantit déjà l'appartenance
        // à { TREND_FOLLOWING, MEAN_REVERSION } ; on garde le garde-fou explicite.
        if (uint8(strategy) > uint8(Strategy.MEAN_REVERSION)) revert UnsupportedStrategy();

        // Validation du capital initial (Req 1.1, 1.6).
        if (initialCapital < MIN_CAPITAL || initialCapital > MAX_CAPITAL) {
            revert InvalidInitialCapital();
        }

        agentId = nextAgentId++;

        // 1) Déployer agent + wallet via le déployeur externe (garde la fabrique
        //    sous la limite de taille EIP-170). La fabrique reste l'autorité.
        (address agentAddr, address walletAddr) = deployer.deploy(
            address(this), agentOwner, agentId, strategy, address(market), address(leaderboard)
        );
        agent = agentAddr;

        // 2) Câbler le wallet sur l'agent (la fabrique est `factory` autorisée).
        TradingAgent(payable(agentAddr)).setWallet(walletAddr);

        // 3) Enregistrer auprès du marché (capital initial + contrôleur = l'agent).
        //    La fabrique doit être la `factory` autorisée du SimpleMarket.
        _registerOnMarket(agentId, agent, initialCapital);

        // 4) Exposer immédiatement dans le leaderboard (score nul au départ).
        //    La fabrique est le `registrar` du Leaderboard → trackAgent autorisé.
        leaderboard.trackAgent(agentId);

        // 5) Enregistrer dans le registre consultable (Req 1.4).
        _agents[agentId] = AgentRecord({
            agent: agent,
            owner: agentOwner,
            wallet: walletAddr,
            strategy: strategy,
            status: AgentStatus.ACTIVE
        });
        _agentIds.push(agentId);

        emit AgentCreated(agentId, agent, agentOwner, strategy);
    }

    /// @dev Appel séparé pour gérer l'interface d'enregistrement du marché.
    function _registerOnMarket(uint256 agentId, address controller, uint256 initialCapital)
        internal
    {
        // SimpleMarket.registerAgent(agentId, controller, initialCapital)
        (bool ok, ) = address(market).call(
            abi.encodeWithSignature(
                "registerAgent(uint256,address,uint256)", agentId, controller, initialCapital
            )
        );
        require(ok, "market register failed");
    }

    // ─────────────────────────────────────────────────────────────────────
    // Cycle de vie
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc IAgentFactory
    /// @dev Réservé au propriétaire enregistré (Req 1.8, 9.3/9.4). Rejette si déjà
    ///      retiré (Req 1.9).
    function retireAgent(uint256 agentId) external override {
        AgentRecord storage rec = _agents[agentId];
        if (rec.agent == address(0)) revert AgentNotFound();
        if (msg.sender != rec.owner) revert Unauthorized(); // Req 1.8
        if (rec.status == AgentStatus.RETIRED) revert AlreadyRetired(); // Req 1.9

        rec.status = AgentStatus.RETIRED;
        TradingAgent(payable(rec.agent)).markRetired();
        emit AgentRetired(agentId);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Lectures (Req 1.4)
    // ─────────────────────────────────────────────────────────────────────

    /// @inheritdoc IAgentFactory
    function getAgent(uint256 agentId) external view override returns (AgentRecord memory) {
        if (_agents[agentId].agent == address(0)) revert AgentNotFound();
        return _agents[agentId];
    }

    /// @inheritdoc IAgentFactory
    function listAgents() external view override returns (AgentRecord[] memory list) {
        uint256 n = _agentIds.length;
        list = new AgentRecord[](n);
        for (uint256 i = 0; i < n; i++) {
            list[i] = _agents[_agentIds[i]];
        }
    }

    /// @inheritdoc IAgentFactory
    function activeAgentCount() external view override returns (uint256 count) {
        uint256 n = _agentIds.length;
        for (uint256 i = 0; i < n; i++) {
            if (_agents[_agentIds[i]].status == AgentStatus.ACTIVE) count++;
        }
    }

    /// @notice Nombre total d'agents créés.
    function totalAgents() external view returns (uint256) {
        return _agentIds.length;
    }
}
