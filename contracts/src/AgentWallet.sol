// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRitualWallet, IScheduler} from "./interfaces/IRitualSystem.sol";
import {RitualAddresses} from "./RitualAddresses.sol";

/// @title AgentWallet
/// @notice Wallet dédié à un unique Trading_Agent (Req 2). Chaque agent possède
///         son propre AgentWallet, déployé par l'AgentFactory, ce qui lui donne
///         une adresse distincte non partagée (Property 1) et satisfait la
///         contrainte « un seul job async direct en attente par expéditeur »
///         de l'AsyncJobTracker (Req 2.1).
///
/// @dev Le wallet encapsule les dépôts verrouillés dans le RitualWallet système
///      (Req 2.2, 2.4) et permet le retrait d'urgence du capital non engagé vers
///      l'owner (Req 9.6, 9.7). Seuls l'owner (déclencheur d'urgence) et l'agent
///      associé (opérations courantes) peuvent agir.
contract AgentWallet {
    // ── Erreurs ──
    error Unauthorized();
    error ZeroDeposit();
    error WithdrawFailed();

    // ── État ──
    /// @notice Propriétaire (humain) autorisé au retrait d'urgence (Req 9.6).
    address public immutable owner;

    /// @notice Contrat TradingAgent associé à ce wallet.
    address public immutable agent;

    /// @notice Identifiant de l'agent dans la fabrique/marché.
    uint256 public immutable agentId;

    /// @notice Total déposé (crédité) via ce wallet, en RITUAL (Req 2.2).
    uint256 public totalDeposited;

    // ── Événements ──
    event Deposited(address indexed from, uint256 amount, uint256 lockDuration);
    event DepositFailed(string reason);
    event EmergencyWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrAgent() {
        if (msg.sender != owner && msg.sender != agent) revert Unauthorized();
        _;
    }

    /// @param owner_ Propriétaire humain (Req 9.6).
    /// @param agent_ Contrat TradingAgent associé.
    /// @param agentId_ Identifiant de l'agent.
    constructor(address owner_, address agent_, uint256 agentId_) {
        owner = owner_;
        agent = agent_;
        agentId = agentId_;
    }

    /// @notice Dépose des fonds natifs RITUAL dans le RitualWallet système avec
    ///         verrouillage (Req 2.2, 2.4). Crédite le suivi local du montant exact.
    /// @param lockDuration Durée de verrouillage (en blocs), doit couvrir > currentBlock + ttl.
    function deposit(uint256 lockDuration) external payable onlyOwnerOrAgent {
        if (msg.value == 0) revert ZeroDeposit();
        IRitualWallet(RitualAddresses.RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        // Crédit exact du montant déposé (Req 2.2, Property 16).
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value, lockDuration);
    }

    /// @notice Autorise l'agent associé à utiliser ce wallet comme payer des
    ///         planifications Scheduler (Req 4). Le payer (ce wallet) doit appeler
    ///         Scheduler.approveScheduler(agent) — cf. skill ritual-dapp-scheduler
    ///         (Payer Semantics : sponsor appelle approveScheduler(contract)).
    function approveSchedulerForAgent() external onlyOwnerOrAgent {
        IScheduler(RitualAddresses.SCHEDULER).approveScheduler(agent);
    }

    /// @notice Solde verrouillé/disponible de ce wallet dans le RitualWallet système.
    function ritualBalance() external view returns (uint256) {
        return IRitualWallet(RitualAddresses.RITUAL_WALLET).balanceOf(address(this));
    }

    /// @notice Retrait d'urgence : transfère le solde natif non engagé détenu par
    ///         ce wallet vers l'owner (Req 9.6). En cas d'échec, conserve l'état et
    ///         revert (Req 9.7).
    /// @dev Transfère le solde natif présent sur ce contrat (capital non engagé,
    ///      non verrouillé dans le RitualWallet système).
    function emergencyWithdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert WithdrawFailed(); // Req 9.7 : état inchangé sur échec
        emit EmergencyWithdrawn(owner, amount);
    }

    /// @notice Réception de fonds natifs (capital non engagé pré-dépôt).
    receive() external payable {}
}
