// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strategy} from "./interfaces/IRitualSystem.sol";
import {TradingAgent} from "./TradingAgent.sol";
import {AgentWallet} from "./AgentWallet.sol";

/// @title AgentDeployer
/// @notice Contrat déployeur dédié : porte le bytecode lourd de TradingAgent et
///         AgentWallet pour les instancier. Sépare ce bytecode de l'AgentFactory,
///         qui resterait sinon au-dessus de la limite de taille EIP-170 (24 576).
///
/// @dev Pattern recommandé par le skill Ritual (déploiement factory-backed) :
///      la fabrique délègue la création des enfants à un contrat externe, donc
///      elle n'embarque pas leur bytecode. Le déployeur câble `factory` sur la
///      fabrique appelante pour que setWallet/markRetired restent autorisés.
contract AgentDeployer {
    /// @notice Déploie un TradingAgent + son AgentWallet dédié, les câble, et
    ///         renvoie leurs adresses. `factory` (l'appelant) reste la fabrique
    ///         autorisée de l'agent.
    /// @param factory Adresse de l'AgentFactory autorisée (msg.sender côté factory).
    function deploy(
        address factory,
        address agentOwner,
        uint256 agentId,
        Strategy strategy,
        address market,
        address leaderboard
    ) external returns (address agent, address wallet) {
        TradingAgent ta = new TradingAgent(
            agentOwner, agentId, strategy, market, leaderboard, factory
        );
        agent = address(ta);

        AgentWallet aw = new AgentWallet(agentOwner, agent, agentId);
        wallet = address(aw);
    }
}
