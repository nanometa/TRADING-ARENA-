// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strategy, AgentStatus, Decision} from "./interfaces/IRitualSystem.sol";
import {
    IScheduler,
    IAsyncJobTracker,
    ITEEServiceRegistry,
    IRitualWallet
} from "./interfaces/IRitualSystem.sol";
import {ISimpleMarket, ILeaderboard} from "./interfaces/IArena.sol";
import {RitualAddresses} from "./RitualAddresses.sol";
import {RitualLLM} from "./RitualLLM.sol";

/// @title TradingAgent
/// @notice Agent IA autonome de la Ritual Trading Arena. Il s'auto-planifie via le
///         Scheduler natif puis, à chaque réveil, exécute un cycle de décision LLM
///         en deux phases (Req 3, 4, 6, 9) :
///
///   Phase 0 (autoCycle)   — réveil planifié ; ignoré si pause/retrait (Req 4.9) ;
///                           restauration de l'état (Req 6.6).
///   Phase 1 (commitment)  — découverte TEE (Req 3.6/3.8), récupération de prix HTTP,
///                           garde-fous (dépôt verrouillé > block+ttl Req 2.4, capital
///                           suffisant Req 2.5, pas de job en attente), puis appel
///                           LLM 0x0802 → jobId ; contexte mémorisé (Req 3.1/3.2).
///   Phase 2 (onLLMResult) — callback réservé à AsyncDelivery (Req 9.8/9.9) ;
///                           timeout 60 s → HOLD (Req 3.5) ; parsing décision
///                           (Req 3.3/3.4) ; budget glissant (Req 9.1/9.2) ; arrêt
///                           d'urgence (Req 9.5) ; trade atomique + persistance.
///
/// @dev L'adresse de ce contrat sert d'adresse expéditrice distincte (Req 2.1).
contract TradingAgent {
    // ─────────────────────────────────────────────────────────────────────
    // Constantes
    // ─────────────────────────────────────────────────────────────────────

    uint256 internal constant WAD = 1e18;
    uint256 public constant MIN_LLM_FEE_RESERVE = 0.35e18;

    /// @notice Délai de sécurité avant la première exécution Scheduler.
    /// @dev Un départ à +5 blocs a été manqué sur testnet, tandis que +170 blocs
    ///      a été exécuté correctement. Le délai initial reste indépendant de la
    ///      fréquence des récurrences afin de ne pas limiter les stratégies.
    uint32 internal constant MIN_SCHEDULER_LEAD_BLOCKS = 170;

    /// @notice Plafonds Scheduler éprouvés sur Ritual testnet.
    uint256 internal constant SCHEDULER_MAX_FEE_PER_GAS = 1_100_000_000;
    uint256 internal constant SCHEDULER_MAX_PRIORITY_FEE_PER_GAS = 0;

    /// @notice Fenêtre de décision ≈ 60 s à ~350 ms/bloc (Req 3.5).
    uint64 internal constant DECISION_TIMEOUT_BLOCKS = 171;

    // ─────────────────────────────────────────────────────────────────────
    // Erreurs
    // ─────────────────────────────────────────────────────────────────────

    error Unauthorized();
    error AlreadyWired();
    error InvalidAddress();
    error ScheduleLimitExceeded(); // Req 4.6
    error BadCallbackSender(); // Req 9.8/9.9
    error BudgetExceeded(); // Req 9.2
    error WithdrawFailed(); // Req 9.7
    error NotActive();
    error UnsafeFeeReserve();

    // ─────────────────────────────────────────────────────────────────────
    // État cœur
    // ─────────────────────────────────────────────────────────────────────

    address public immutable owner; // propriétaire enregistré (Req 1.3)
    uint256 public immutable agentId;
    Strategy public immutable agentStrategy;

    ISimpleMarket public market;
    ILeaderboard public leaderboard;
    address public wallet; // AgentWallet dédié (Req 2.1)
    address public factory;

    AgentStatus public status; // ACTIVE / RETIRED
    bool public paused;
    bool public emergencyStopped;

    // ── Planification (Req 4) ──
    uint256 public callId;        // cycle d'ANALYSE (autoCycle / LLM)
    uint32 public scheduleTtl;
    // Mémorisés pour permettre l'AUTO-REPLANIFICATION (l'agent se replanifie tout
    // seul à la fin de sa série, pour vivre en continu tant qu'il a des fees).
    uint32 public scheduleFrequency;
    uint32 public scheduleNumCalls;
    /// @notice Désactivé par défaut : un agent neuf commence toujours par un
    ///         cycle one-shot et ne peut pas brûler ses frais en boucle si
    ///         l'infrastructure LLM est indisponible.
    bool public autoReschedule;

    // ── Paramètres de trading / fees ──
    // Quantité par trade. Calibrée avec les réserves du marché (10 000) pour que
    // chaque achat/vente fasse bouger le prix d'environ ~1% (marché "vivant" même
    // avec peu d'agents). Ajustable par l'owner via setTradeSize si besoin.
    uint256 public tradeSize = 100e18;
    // Coût estimé d'un cycle (Req 2.5) : sert de SEUIL de garde-fou. Si le wallet
    // a moins que ça, le cycle est sauté (aucune dépense). Avec GLM-4.7-FP8 à 4096
    // tokens + gas, le pire cas observé est proche de 0,31 RITUAL. Une marge à
    // 0,35 empêche de lancer un appel qui ne pourra pas être réglé.
    uint256 public estimatedCallCost = MIN_LLM_FEE_RESERVE;
    /// @notice Nombre d'erreurs LLM consécutives. Une erreur d'infrastructure
    ///         déclenche immédiatement le circuit breaker pour ne pas brûler les frais.
    uint8 public consecutiveLlmErrors;
    uint256 public depositLockExpiryBlock; // bloc d'expiration du verrou de dépôt (Req 2.4)

    // ── Contexte de décision Phase 1 → Phase 2 ──
    struct DecisionContext {
        uint256 priceSnapshot;
        uint256 capitalSnapshot;
        uint256 positionSnapshot;
        uint64 committedAtBlock;
        bool pending;
    }

    mapping(uint256 => DecisionContext) public pendingDecisions; // jobId => contexte

    // ── Budget glissant (Req 9.1, 9.2) ──
    struct BudgetWindow {
        uint256 limit;
        uint256 windowSeconds;
        uint256 windowStart;
        uint256 spentInWindow;
    }

    BudgetWindow public budget;

    // ── Mémoire de stratégie persistée (Req 6.1, 6.6) ──
    struct StrategyState {
        uint256 lastPrice;
        uint64 lastCycleBlock;
        uint64 cycleCount;
        bool initialized;
    }

    StrategyState public strategyState;

    // ── Oracle de prix externe via HTTP precompile 0x0801 (Req 3.5 contexte) ──
    /// @notice Dernier prix externe récupéré (18 décimales) et son bloc.
    uint256 public externalPrice;
    uint64 public externalPriceBlock;
    /// @notice Fraîcheur maximale (en blocs) d'un prix externe pour être réutilisé.
    uint64 public priceFreshnessBlocks = 600; // ~3.5 min à ~350 ms/bloc
    /// @notice URL de l'API de prix (par défaut Binance BTC/USDT — atteignable par le TEE
    ///         et ÉPROUVÉE on-chain ; cf. contrat oracle ritual-ta-oracle).
    string public priceUrl =
        "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT";
    /// @notice Filtre JQ d'extraction du prix. IMPORTANT : le précompile JQ (0x0803)
    ///         plafonne la sortie numérique à int64 (~9,22e18) ; multiplier par 1e18
    ///         (≈9,5e22 pour BTC) DÉBORDE → valeur tronquée (bug observé). On extrait donc
    ///         le prix en DOLLARS ENTIERS (< int64), SANS ×1e18. Réponse Binance :
    ///         {"symbol":"BTCUSDT","price":"67000.50"} → ".price | tonumber | floor".
    string public priceJqFilter = ".price | tonumber | floor";
    /// @notice Symbole lisible de la paire suivie (pour l'affichage / les logs).
    string public priceSymbol = "BTC/USD";

    /// @notice Modèle LLM utilisé pour le raisonnement (Ritual gateway par défaut).
    string public llmModel = "zai-org/GLM-4.7-FP8";
    /// @notice Plafond de tokens de sortie. GLM-4.7-FP8 est un modèle de RAISONNEMENT
    ///         (bloc <think> qui consomme 500-1500 tokens avant la réponse). Le skill
    ///         officiel `ritual-dapp-llm` impose >= 4096 sinon le `content` revient VIDE
    ///         (finish_reason="length"). On fixe 4096 comme baseline.
    int256 public llmMaxTokens = 4096;
    /// @notice TTL (blocs) de l'appel LLM async. Le raisonnement peut prendre 10-40s ;
    ///         le skill recommande >= 60 (300 par défaut sûr). On fixe 300.
    uint256 public llmTtl = 300;

    // ── Référence DA pour mémoire lourde (Req 6.2) ──
    /// @notice Plateforme DA (hf/gcs/pinata) et chemin du checkpoint de mémoire.
    string public daPlatform;
    string public daPath;
    /// @notice Seuil (octets) au-delà duquel la mémoire bascule vers la DA.
    uint256 public onchainMemoryThreshold = 8_192;

    // ─────────────────────────────────────────────────────────────────────
    // Événements
    // ─────────────────────────────────────────────────────────────────────

    event Wired(address indexed wallet);
    event Retired();
    event Activated(uint256 indexed callId, uint32 frequency, uint32 numCalls, uint32 ttl);
    event Paused();
    event Resumed();
    event EmergencyStopped();
    event EmergencyWithdrawn(uint256 amount);
    event BudgetLimitSet(uint256 limit, uint256 windowSeconds);

    event CycleStarted(uint256 indexed executionIndex);
    event CycleIgnored(uint256 indexed executionIndex, string reason); // pause/retrait (Req 4.9)
    event LLMRequested(uint256 indexed jobId, uint256 price);
    event LLMFailed(uint256 indexed jobId, string reason, uint8 consecutiveFailures);
    event CircuitBreakerTripped(uint256 indexed jobId, string reason);
    event TeeUnavailable(); // Req 3.7
    event InsufficientCapital(); // Req 2.5
    event DepositLockTooShort(); // Req 2.4
    event PendingJobSkipped(); // un seul job direct par expéditeur
    event DecisionMade(uint256 indexed jobId, uint8 decision);
    event DecisionAnomaly(uint256 indexed jobId, string reason); // Req 3.4
    event DecisionTimeout(uint256 indexed jobId); // Req 3.5
    event BudgetBreach(uint256 requested, uint256 limit, uint256 timestamp); // Req 9.2
    event CycleFailed(uint256 indexed jobId, string reason); // Req 4.8
    event StatePersisted(uint64 cycleCount, uint256 lastPrice); // Req 6.1
    event PriceRequested(address executor, string url); // oracle HTTP Phase 1
    event PriceUpdated(uint256 price, uint64 blockNumber); // oracle HTTP Phase 2
    event DaCheckpointSet(string platform, string path); // Req 6.2

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

    modifier onlyScheduler() {
        if (msg.sender != RitualAddresses.SCHEDULER) revert Unauthorized();
        _;
    }

    /// @dev Réservé au contrat système AsyncDelivery (Req 9.8/9.9).
    modifier onlyAsyncDelivery() {
        if (msg.sender != RitualAddresses.ASYNC_DELIVERY) revert BadCallbackSender();
        _;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Construction & câblage
    // ─────────────────────────────────────────────────────────────────────

    constructor(
        address owner_,
        uint256 agentId_,
        Strategy strategy_,
        address market_,
        address leaderboard_,
        address factory_
    ) {
        if (owner_ == address(0) || market_ == address(0) || leaderboard_ == address(0)) {
            revert InvalidAddress();
        }
        owner = owner_;
        agentId = agentId_;
        agentStrategy = strategy_;
        market = ISimpleMarket(market_);
        leaderboard = ILeaderboard(leaderboard_);
        // La fabrique autorisée (setWallet/markRetired). Passée explicitement car
        // le déploiement passe par un AgentDeployer (msg.sender != fabrique).
        factory = factory_ == address(0) ? msg.sender : factory_;
        status = AgentStatus.ACTIVE;
    }

    function setWallet(address wallet_) external onlyFactory {
        if (wallet != address(0)) revert AlreadyWired();
        if (wallet_ == address(0)) revert InvalidAddress();
        wallet = wallet_;
        emit Wired(wallet_);
    }

    function markRetired() external onlyFactory {
        status = AgentStatus.RETIRED;
        emit Retired();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Configuration (owner)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Définit le Budget_Limit et la fenêtre glissante (Req 9.1).
    function setBudgetLimit(uint256 limit, uint256 windowSeconds) external onlyOwner {
        budget.limit = limit;
        budget.windowSeconds = windowSeconds;
        budget.windowStart = block.timestamp;
        budget.spentInWindow = 0;
        emit BudgetLimitSet(limit, windowSeconds);
    }

    function setTradeSize(uint256 size) external onlyOwner {
        tradeSize = size;
    }

    function setEstimatedCallCost(uint256 cost) external onlyOwner {
        if (cost < MIN_LLM_FEE_RESERVE) revert UnsafeFeeReserve();
        estimatedCallCost = cost;
    }

    /// @notice Enregistre le bloc d'expiration du verrou de dépôt RitualWallet (Req 2.4).
    function recordDepositLock(uint256 expiryBlock) external {
        if (msg.sender != owner && msg.sender != wallet && msg.sender != factory) {
            revert Unauthorized();
        }
        depositLockExpiryBlock = expiryBlock;
    }

    /// @notice Approvisionne l'escrow de frais async DE CET AGENT lui-même.
    /// @dev Le precompile LLM (0x0802) débite l'escrow du contrat APPELANT, c'est-à-dire
    ///      CET agent — pas l'AgentWallet. Les frais doivent donc être déposés dans le
    ///      RitualWallet système au crédit de `address(this)`. C'est l'agent qui appelle
    ///      `deposit()`, donc `msg.sender` côté RitualWallet est bien cet agent.
    ///      Verrou suffisamment long pour couvrir block + ttl (Req 2.4).
    /// @param lockDuration Durée de verrouillage (en blocs).
    function fundFees(uint256 lockDuration) external payable {
        if (msg.sender != owner && msg.sender != wallet && msg.sender != factory) {
            revert Unauthorized();
        }
        IRitualWallet(RitualAddresses.RITUAL_WALLET).deposit{value: msg.value}(lockDuration);
        depositLockExpiryBlock = block.number + lockDuration;
    }

    /// @notice Récupère l'escrow de frais inutilisé après expiration du verrou.
    /// @dev RitualWallet crédite d'abord ce contrat, qui retransfère atomiquement
    ///      le même montant à l'owner. RitualWallet rejette si le verrou est actif.
    function withdrawFeeEscrow(uint256 amount) external onlyOwner {
        IRitualWallet(RitualAddresses.RITUAL_WALLET).withdraw(amount);
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert WithdrawFailed();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Activation / planification (Req 4)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Planifie les cycles périodiques via le Scheduler (Req 4.1–4.6).
    /// @dev Seul un contrat peut appeler Scheduler.schedule() ; c'est bien le cas ici
    ///      car l'appelant du precompile est ce contrat (Req 4.2).
    function activate(uint32 frequency, uint32 numCalls, uint32 ttl) external onlyOwner {
        if (status != AgentStatus.ACTIVE) revert NotActive();

        // Validation des bornes (Req 4.4, 4.5, 4.6).
        if (frequency < 1 || numCalls < 1) revert ScheduleLimitExceeded();
        if (uint256(frequency) * uint256(numCalls) > RitualAddresses.MAX_LIFESPAN) {
            revert ScheduleLimitExceeded();
        }
        if (ttl < 1 || ttl > RitualAddresses.MAX_TTL) revert ScheduleLimitExceeded();

        scheduleTtl = ttl;
        scheduleFrequency = frequency;
        scheduleNumCalls = numCalls;

        // payer == msg.sender == cet agent : aucune approveScheduler n'est requise.
        // L'approbation n'est nécessaire que pour un sponsor tiers et son coût
        // système rendait inutilement l'activation extrêmement chère.
        // UNE SEULE planification. Chaque exécution lance directement le LLM puis
        // le trade. Le prix HTTP reste un rafraîchissement séparé et optionnel :
        // il ne peut donc plus empêcher l'analyse si le keeper ne sert qu'un appel.
        callId = _schedule(frequency, numCalls, ttl); // planifie autoCycle
        emit Activated(callId, frequency, numCalls, ttl);
    }

    /// @dev Crée une planification Scheduler avec les paramètres donnés. Réutilisé
    ///      par activate() et par l'auto-replanification (Req 4.1).
    function _schedule(uint32 frequency, uint32 numCalls, uint32 ttl)
        internal
        returns (uint256 newCallId)
    {
        // Planifie le cycle autonome LLM → décision → trade.
        newCallId = _scheduleCall(
            this.autoCycle.selector,
            uint32(block.number) + MIN_SCHEDULER_LEAD_BLOCKS,
            frequency,
            numCalls,
            ttl
        );
    }

    /// @dev Planifie un appel récurrent d'un sélecteur donné,
    ///      payer = cet agent (modèle ritual-ta-oracle). 1er param du callback =
    ///      executionIndex factice (octets 4-35), écrasé par le système (Req 4.7).
    function _scheduleCall(
        bytes4 selector, uint32 startBlock, uint32 frequency, uint32 numCalls, uint32 ttl
    ) internal returns (uint256 cid) {
        bytes memory data = abi.encodeWithSelector(selector, uint256(0), uint256(0));
        cid = IScheduler(RitualAddresses.SCHEDULER).schedule(
            data,
            uint32(3_500_000), // gas/exec : couvre l'appel précompile (HTTP ou LLM) + replay
            startBlock,
            numCalls,
            frequency,
            ttl,
            // Valeurs éprouvées on-chain : le problème précédent venait du délai
            // initial trop court, pas d'un manque de frais Scheduler.
            SCHEDULER_MAX_FEE_PER_GAS,
            SCHEDULER_MAX_PRIORITY_FEE_PER_GAS,
            uint256(0), // value
            address(this) // payer = l'agent lui-même (pool RitualWallet pré-financé)
        );
    }

    /// @notice Active/désactive l'auto-replanification (owner). Quand activée,
    ///         l'agent recrée une planification à la fin de sa série pour tourner
    ///         en continu tant que le wallet a des fees.
    function setAutoReschedule(bool enabled) external onlyOwner {
        autoReschedule = enabled;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function resume() external onlyOwner {
        paused = false;
        emit Resumed();
    }

    /// @notice Arrêt d'urgence : l'agent cesse d'engager du capital (Req 9.5).
    function emergencyStop() external onlyOwner {
        emergencyStopped = true;
        emit EmergencyStopped();
    }

    /// @notice Retrait d'urgence : transfère le capital non engagé vers l'owner (Req 9.6/9.7).
    function emergencyWithdraw() external onlyOwner {
        // Délègue au wallet dédié, qui transfère son solde natif vers l'owner.
        (bool ok, ) = wallet.call(abi.encodeWithSignature("emergencyWithdraw()"));
        if (!ok) revert WithdrawFailed(); // Req 9.7 : état inchangé sur échec
        emit EmergencyWithdrawn(0);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Phase 0 — réveil planifié
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Cycle autonome planifié : chaque exécution lance directement le LLM,
    ///         applique sa décision et trade. Un seul async court par exécution.
    ///         L'oracle HTTP est optionnel et se rafraîchit via requestPrice.
    function autoCycle(uint256 executionIndex, uint256 /* seriesId */) external onlyScheduler {
        _runScheduledCycle(executionIndex);
    }

    function _runScheduledCycle(uint256 executionIndex) internal {
        if (paused || status == AgentStatus.RETIRED) {
            emit CycleIgnored(executionIndex, "paused_or_retired");
            return;
        }

        emit CycleStarted(executionIndex);
        _restoreState();
        _commitDecision();

        // Auto-replanification au dernier cycle (best-effort) pour vivre en continu.
        if (
            autoReschedule
            && scheduleNumCalls > 0
            && executionIndex + 1 >= scheduleNumCalls
        ) {
            try this.rescheduleSelf() {} catch {
                emit CycleFailed(0, "reschedule_failed");
            }
        }
    }

    /// @notice Recrée une planification (auto-replanification). Appelable seulement
    ///         par ce contrat lui-même (via autoCycle) ou par l'owner.
    function rescheduleSelf() external {
        if (msg.sender != address(this) && msg.sender != owner) revert Unauthorized();
        if (status != AgentStatus.ACTIVE || paused) return;
        if (scheduleFrequency == 0 || scheduleNumCalls == 0) return;

        callId = _schedule(scheduleFrequency, scheduleNumCalls, scheduleTtl);
        emit Activated(callId, scheduleFrequency, scheduleNumCalls, scheduleTtl);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Phase 1 — commitment synchrone
    // ─────────────────────────────────────────────────────────────────────

    function _commitDecision() internal {
        // 1) Découverte d'un exécuteur TEE LLM (capacité LLM = 1 — skill ritual-dapp-llm ;
        //    jamais hardcodé, Req 3.6/3.8). cap-0 (HTTP) et cap-1 (LLM) sont distincts.
        (address tee, bool found) = _executorFor(RitualAddresses.CAP_LLM);
        if (!found) {
            emit TeeUnavailable(); // Req 3.7 → HOLD
            return;
        }

        // 2) Prix en cache HTTP s'il est frais, sinon prix on-chain. Aucun second
        //    appel async n'est lancé dans cette transaction LLM.
        uint256 price = _fetchPrice(tee);

        // 3) Garde-fou : verrou de dépôt couvrant le ttl (Req 2.4, Property 7).
        if (depositLockExpiryBlock <= block.number + scheduleTtl) {
            emit DepositLockTooShort();
            return;
        }

        // 4) Garde-fou : capital suffisant pour l'appel (Req 2.5, Property 17).
        if (_availableForFees() < estimatedCallCost) {
            emit InsufficientCapital();
            if (!paused) {
                paused = true;
                emit Paused();
            }
            return;
        }

        // 5) NOTE (fix autopilote) : on N'utilise PLUS le garde `hasPendingJobForSender` ici.
        //    Le tracker garde un job "en attente" TRÈS longtemps après règlement (>2500 blocs
        //    observés on-chain), bien au-delà du verrou réel du mempool (libéré au règlement).
        //    Ce garde faisait donc SAUTER l'analyse à tort en cycle autonome. On tente désormais
        //    le commit LLM directement ; si l'expéditeur est réellement verrouillé, _submitLLM
        //    échoue proprement (soft-skip SANS revert, cf. _submitLLM).

        // 6) Appel LLM 0x0802 (short-running async). Sur la ré-exécution (fulfilled
        //    replay — skill ritual-dapp-llm), `ret` contient la SORTIE RÉGLÉE du LLM ;
        //    on la décode et on agit DANS LA MÊME TX (pas de callback onLLMResult).
        (uint256 jobId, bytes memory ret) = _submitLLM(tee, price);
        emit LLMRequested(jobId, price);

        // Phase de simulation/commitment : la sortie réglée n'est pas encore injectée
        // (`actualOutput` vide). Le cycle se complète sur le fulfilled-replay (même tx),
        // comme le contrat oracle ritual-ta-oracle (`if (actualOutput.length == 0) return`).
        if (ret.length == 0) {
            return;
        }

        // Une erreur d'infrastructure LLM n'est PAS une décision HOLD. Elle coupe
        // l'agent sans persister un faux cycle et sans engager de capital.
        (Decision d, bool llmFailed) = _resolveLLMResult(jobId, ret);
        if (llmFailed) return;
        emit DecisionMade(jobId, uint8(d));

        if (d == Decision.HOLD) {
            _persistState(price);
            return;
        }
        if (emergencyStopped) {
            emit CycleFailed(jobId, "emergency_stopped"); // Req 9.5
            _persistState(price);
            return;
        }

        // Exécution du trade dans la même tx (Property 9/12), puis persistance (Req 6.1).
        _executeDecision(jobId, d);
        _persistState(price);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Phase 2 — callback LLM
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Callback de résultat LLM, réservé à AsyncDelivery (Req 9.8/9.9).
    function onLLMResult(uint256 /* executionIndex */, uint256 jobId, bytes calldata result)
        external
        onlyAsyncDelivery
    {
        DecisionContext memory ctx = pendingDecisions[jobId];
        // Job inconnu / déjà consommé → ignorer sans effet.
        if (!ctx.pending) {
            emit DecisionAnomaly(jobId, "unknown_or_consumed");
            return;
        }

        // Consommer le contexte (anti-rejeu).
        delete pendingDecisions[jobId];

        // Timeout 60 s (Req 3.5, Property 18) → HOLD, état inchangé.
        if (block.number > ctx.committedAtBlock + DECISION_TIMEOUT_BLOCKS) {
            emit DecisionTimeout(jobId);
            _persistState(ctx.priceSnapshot);
            return;
        }

        // Une enveloppe `hasError=true` coupe l'agent au lieu de devenir un faux HOLD.
        (Decision d, bool llmFailed) = _resolveLLMResult(jobId, result);
        if (llmFailed) return;
        emit DecisionMade(jobId, uint8(d));

        if (d == Decision.HOLD) {
            // « ne rien faire » — aucun engagement de capital.
            _persistState(ctx.priceSnapshot);
            return;
        }

        // Arrêt d'urgence : aucun engagement de capital (Req 9.5, Property 21).
        if (emergencyStopped) {
            emit CycleFailed(jobId, "emergency_stopped");
            _persistState(ctx.priceSnapshot);
            return;
        }

        // Exécution du trade (atomique côté marché ; Property 9/12).
        _executeDecision(jobId, d);

        // Persistance de fin de cycle (Req 6.1).
        _persistState(ctx.priceSnapshot);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Exécution de la décision
    // ─────────────────────────────────────────────────────────────────────

    function _executeDecision(uint256 jobId, Decision d) internal {
        if (d == Decision.BUY) {
            uint256 price = market.currentPrice();
            uint256 cost = (tradeSize * price) / WAD;

            // Budget glissant (Req 9.1/9.2, Property 20).
            if (!_budgetAllows(cost)) {
                emit BudgetBreach(cost, budget.limit, block.timestamp);
                emit CycleFailed(jobId, "budget_exceeded");
                return; // refus total, capital inchangé
            }

            // Achat atomique sur le marché ; en cas d'échec, état inchangé (Property 12).
            try market.buy(agentId, tradeSize) returns (uint256 spent) {
                _recordSpend(spent);
            } catch {
                emit CycleFailed(jobId, "buy_failed");
            }
        } else {
            // SELL : limiter à la position détenue.
            uint256 pos = market.positionOf(agentId);
            uint256 qty = tradeSize > pos ? pos : tradeSize;
            if (qty == 0) {
                emit CycleFailed(jobId, "no_position");
                return;
            }
            try market.sell(agentId, qty) {
                // vente : pas de consommation de budget (libère du capital)
            } catch {
                emit CycleFailed(jobId, "sell_failed");
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Budget glissant
    // ─────────────────────────────────────────────────────────────────────

    /// @dev Vrai si `amount` peut être engagé sans dépasser le Budget_Limit sur la
    ///      fenêtre glissante courante. Réinitialise la fenêtre si expirée.
    function _budgetAllows(uint256 amount) internal returns (bool) {
        // Budget non configuré (limit == 0) → pas de contrainte.
        if (budget.limit == 0) return true;

        // Réinitialisation de la fenêtre glissante si expirée.
        if (block.timestamp >= budget.windowStart + budget.windowSeconds) {
            budget.windowStart = block.timestamp;
            budget.spentInWindow = 0;
        }

        return budget.spentInWindow + amount <= budget.limit;
    }

    function _recordSpend(uint256 amount) internal {
        if (budget.limit == 0) return;
        budget.spentInWindow += amount;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Persistance / restauration (Req 6.1, 6.6)
    // ─────────────────────────────────────────────────────────────────────

    function _persistState(uint256 lastPrice) internal {
        strategyState.lastPrice = lastPrice;
        strategyState.lastCycleBlock = uint64(block.number);
        strategyState.cycleCount += 1;
        strategyState.initialized = true;
        emit StatePersisted(strategyState.cycleCount, lastPrice);
    }

    function _restoreState() internal view {
        // Capital/position sont la source de vérité du marché (déjà persistés on-chain).
        // L'état de stratégie est lu depuis `strategyState` (storage), donc déjà restauré.
        // Fonction conservée pour la traçabilité du cycle (Req 6.6).
    }

    // ─────────────────────────────────────────────────────────────────────
    // Parsing de décision (Req 3.3/3.4)
    // ─────────────────────────────────────────────────────────────────────

    /// @dev Distingue une vraie décision HOLD d'une erreur vLLM/registre/exécuteur.
    ///      Les erreurs sont bornées dans les logs puis déclenchent le circuit breaker.
    function _resolveLLMResult(uint256 jobId, bytes memory result)
        internal
        returns (Decision decision, bool failed)
    {
        try this.extractResult(result) returns (
            string memory content,
            bool decodeFailed,
            string memory errorMessage
        ) {
            if (decodeFailed) {
                _recordLlmFailure(jobId, errorMessage);
                return (Decision.HOLD, true);
            }
            consecutiveLlmErrors = 0;
            return (_decisionFromText(content), false);
        } catch {
            _recordLlmFailure(jobId, "malformed_llm_response");
            return (Decision.HOLD, true);
        }
    }

    function _recordLlmFailure(uint256 jobId, string memory reason) internal {
        if (consecutiveLlmErrors < type(uint8).max) consecutiveLlmErrors += 1;
        string memory boundedReason = _truncate(reason, 256);
        emit LLMFailed(jobId, boundedReason, consecutiveLlmErrors);

        if (!paused) {
            paused = true;
            emit CircuitBreakerTripped(jobId, boundedReason);
            emit Paused();
        }
    }

    /// @dev Helper externe complet : permet de capturer proprement tout abi.decode
    ///      invalide tout en conservant le message d'erreur de l'enveloppe Ritual.
    function extractResult(bytes calldata b)
        external
        pure
        returns (string memory content, bool failed, string memory errorMessage)
    {
        return RitualLLM.decodeResult(b);
    }

    /// @dev Cherche un mot-clé de décision dans le texte du LLM (tolérant : le
    ///      modèle peut répondre "BUY", "buy", "I recommend BUY", "SELL now", etc.).
    function _decisionFromText(string memory s) internal pure returns (Decision) {
        bytes memory b = bytes(s);
        if (_contains(b, "BUY") || _contains(b, "buy") || _contains(b, "ACHETER")) {
            return Decision.BUY;
        }
        if (_contains(b, "SELL") || _contains(b, "sell") || _contains(b, "VENDRE")) {
            return Decision.SELL;
        }
        return Decision.HOLD;
    }

    /// @dev Recherche naïve de sous-chaîne (needle court, haystack borné).
    function _contains(bytes memory haystack, string memory needleStr)
        internal
        pure
        returns (bool)
    {
        bytes memory needle = bytes(needleStr);
        if (needle.length == 0 || haystack.length < needle.length) return false;
        // Borne de sécurité sur la longueur scannée (anti-gas).
        uint256 maxScan = haystack.length > 2048 ? 2048 : haystack.length;
        for (uint256 i = 0; i + needle.length <= maxScan; i++) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function _truncate(string memory value, uint256 maxLength)
        internal
        pure
        returns (string memory)
    {
        bytes memory source = bytes(value);
        if (source.length <= maxLength) return value;
        bytes memory shortened = new bytes(maxLength);
        for (uint256 i = 0; i < maxLength; i++) shortened[i] = source[i];
        return string(shortened);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Appels aux precompiles / contrats système (mockables en test)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Exécuteur TEE mis en cache par capacité (0=HTTP, 1=LLM), renseigné
    ///         hors-chaîne par l'owner (modèle de découverte du skill ritual-dapp-http).
    ///         Évite la copie en mémoire de TOUT le registre TEE on-chain : sur testnet
    ///         la liste HTTP fait ~22 Ko (40 exécuteurs) → explosion du gas (×2 sim+replay).
    mapping(uint8 => address) public cachedExecutor;

    /// @notice Renseigne l'exécuteur TEE d'une capacité (owner). À découvrir hors-chaîne
    ///         via TEEServiceRegistry.getServicesByCapability(capability, true).
    function setExecutor(uint8 capability, address executor) external onlyOwner {
        cachedExecutor[capability] = executor;
    }

    /// @dev Exécuteur pour une capacité : privilégie le cache (hors-chaîne), sinon
    ///      retombe sur la découverte on-chain (coûteuse si le registre est volumineux).
    function _executorFor(uint8 capability) internal view returns (address tee, bool found) {
        address cached = cachedExecutor[capability];
        if (cached != address(0)) {
            return (cached, true);
        }
        return _discoverExecutor(capability);
    }

    /// @dev Découverte d'un exécuteur TEE valide pour une capacité donnée :
    ///      0 = HTTP_CALL (oracle de prix), 1 = LLM (inférence 0x0802 — skill
    ///      ritual-dapp-llm : `Capability.LLM = 1`). HTTP et LLM sont des ensembles
    ///      d'exécuteurs distincts.
    function _discoverExecutor(uint8 capability) internal view returns (address tee, bool found) {
        ITEEServiceRegistry.Service[] memory services = ITEEServiceRegistry(
            RitualAddresses.TEE_REGISTRY
        ).getServicesByCapability(capability, true);

        for (uint256 i = 0; i < services.length; i++) {
            if (
                services[i].isValid
                    && services[i].node.teeAddress != address(0)
                    && services[i].node.publicKey.length > 0
            ) {
                return (services[i].node.teeAddress, true);
            }
        }
        return (address(0), false);
    }

    /// @dev Récupère un prix de marché. Utilise le dernier prix externe (HTTP) s'il
    ///      est frais ; sinon retombe sur le prix on-chain de l'AMM. Voir
    ///      requestPrice() pour rafraîchir le prix externe via le precompile HTTP.
    function _fetchPrice(address /* tee */) internal view returns (uint256) {
        if (
            externalPrice > 0
                && uint64(block.number) <= externalPriceBlock + priceFreshnessBlocks
        ) {
            return externalPrice;
        }
        return market.currentPrice();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Oracle de prix externe — HTTP precompile 0x0801 (async 2 phases)
    // ─────────────────────────────────────────────────────────────────────

    /// @notice Demande un prix externe via le HTTP precompile (0x0801). Découvre
    ///         l'exécuteur TEE dynamiquement (Req 3.6/3.8). Le résultat arrive en
    ///         Phase 2 sur onPriceResult (réservé à AsyncDelivery).
    /// @dev Encodage conforme au skill ritual-dapp-http (13 champs).
    function requestPrice() external onlyOwner {
        _fetchPriceFromHttp();
    }

    /// @dev Récupère le prix externe via HTTP 0x0801 et le met en cache EN-TX
    ///      (déballage async + JQ). Appelé séparément du cycle LLM.
    function _fetchPriceFromHttp() internal {
        // Oracle de prix via HTTP (0x0801) → exécuteur capacité HTTP_CALL = 0.
        (address tee, bool found) = _executorFor(RitualAddresses.CAP_HTTP_CALL);
        if (!found) {
            emit TeeUnavailable();
            return;
        }

        string[] memory headerKeys = new string[](1);
        string[] memory headerValues = new string[](1);
        headerKeys[0] = "Accept";
        headerValues[0] = "application/json";

        bytes memory input = abi.encode(
            tee, // executor
            new bytes[](0), // encryptedSecrets
            uint256(100), // ttl
            new bytes[](0), // secretSignatures
            bytes(""), // userPublicKey
            priceUrl, // url
            uint8(1), // method = GET
            headerKeys, // headerKeys
            headerValues, // headerValues
            bytes(""), // body
            uint256(0), // dkmsKeyIndex
            uint8(0), // dkmsKeyFormat
            false // piiEnabled
        );

        (bool ok, bytes memory raw) = RitualAddresses.HTTP_PRECOMPILE.call(input);
        require(ok, "HTTP price request failed");
        emit PriceRequested(tee, priceUrl);

        // Lecture EN-TX (modèle short-running async / fulfilled-replay, comme ritual-ta-oracle) :
        // déballer (bytes simmedInput, bytes actualOutput). En simulation `actualOutput` est vide ;
        // sur le replay il porte la réponse HTTP → on en extrait le prix via JQ (0x0803, sync).
        (, bytes memory actualOutput) = abi.decode(raw, (bytes, bytes));
        if (actualOutput.length == 0) {
            return; // phase simulation/commitment ; le prix arrive sur le replay
        }
        try this.extractPriceViaJq(actualOutput) returns (uint256 price) {
            if (price > 0) {
                externalPrice = price;
                externalPriceBlock = uint64(block.number);
                emit PriceUpdated(price, externalPriceBlock);
            }
        } catch {
            // Décodage impossible → conserver le dernier prix valide (fallback AMM).
        }
    }

    /// @notice Callback du résultat HTTP (Phase 2), réservé à AsyncDelivery (Req 9.8).
    ///         Décode la réponse HTTP, extrait le body JSON, puis utilise le
    ///         precompile JQ (0x0803, synchrone) pour en extraire le prix en WAD.
    ///         Met le prix en cache on-chain.
    /// @dev Tout échec (réponse vide, JSON inattendu, JQ KO) conserve le dernier
    ///      prix valide → fallback automatique sur le prix de l'AMM interne.
    function onPriceResult(
        uint256, /* executionIndex */
        bytes32, /* jobId */
        bytes calldata result
    ) external onlyAsyncDelivery {
        // 1) Format "prix déjà décodé" (uint256 WAD) : EXACTEMENT 32 octets.
        //    (chemin simple / tests). Au-delà, c'est une réponse HTTP structurée.
        if (result.length == 32) {
            try this.decodeUint(result) returns (uint256 direct) {
                if (direct > 0) {
                    externalPrice = direct;
                    externalPriceBlock = uint64(block.number);
                    emit PriceUpdated(direct, externalPriceBlock);
                }
            } catch {
                // ignore
            }
            return;
        }

        // 2) Format réel : réponse HTTP { status, headers, body, error } → JQ sur body.
        try this.extractPriceViaJq(result) returns (uint256 price) {
            if (price > 0) {
                externalPrice = price;
                externalPriceBlock = uint64(block.number);
                emit PriceUpdated(price, externalPriceBlock);
            }
        } catch {
            // Décodage impossible → on conserve le dernier prix valide (fallback AMM).
        }
    }

    /// @dev Helper externe (pour try/catch) : décode la réponse HTTP, isole le body
    ///      JSON et appelle le precompile JQ pour extraire le prix en WAD (uint256).
    function extractPriceViaJq(bytes calldata httpResult) external returns (uint256) {
        // La réponse HTTP est encodée : (uint16 status, string[] hk, string[] hv,
        // bytes body, string errorMessage). On ne lit que status + body.
        (uint16 httpStatus, , , bytes memory body, ) = abi.decode(
            httpResult,
            (uint16, string[], string[], bytes, string)
        );
        require(httpStatus >= 200 && httpStatus < 300, "HTTP non-2xx");
        require(body.length > 0, "empty body");

        // JQ (0x0803) synchrone : (string query, string inputData, uint8 outputType).
        // outputType = 1 → uint256.
        bytes memory jqInput = abi.encode(priceJqFilter, string(body), uint8(1));
        (bool ok, bytes memory out) = RitualAddresses.JQ_PRECOMPILE.call(jqInput);
        require(ok && out.length >= 32, "JQ failed");
        return abi.decode(out, (uint256));
    }

    /// @dev Helper externe pour try/catch sur le décodage d'un uint256.
    function decodeUint(bytes calldata b) external pure returns (uint256) {
        return abi.decode(b, (uint256));
    }

    /// @notice Configure l'URL de l'oracle de prix et la fraîcheur (owner).
    function setPriceConfig(string calldata url, uint64 freshnessBlocks) external onlyOwner {
        priceUrl = url;
        priceFreshnessBlocks = freshnessBlocks;
    }

    /// @notice Configure la paire complète suivie (owner) : URL de l'API, filtre JQ
    ///         d'extraction du prix (sortie en WAD entier), symbole lisible et
    ///         fraîcheur. Permet de basculer BTC/USD → ETH/USD, etc., sans redéploy.
    /// @param url URL de l'API de prix (ex. CoinGecko).
    /// @param jqFilter Filtre JQ produisant un entier WAD (ex.
    ///        "(.bitcoin.usd * 1000000000000000000) | floor").
    /// @param symbol Symbole lisible (ex. "BTC/USD").
    /// @param freshnessBlocks Fraîcheur max d'un prix avant rafraîchissement.
    function setPricePair(
        string calldata url,
        string calldata jqFilter,
        string calldata symbol,
        uint64 freshnessBlocks
    ) external onlyOwner {
        priceUrl = url;
        priceJqFilter = jqFilter;
        priceSymbol = symbol;
        priceFreshnessBlocks = freshnessBlocks;
    }

    /// @notice Configure une référence DA pour la mémoire lourde (Req 6.2) (owner).
    function setDaCheckpoint(
        string calldata platform,
        string calldata path,
        uint256 threshold
    ) external onlyOwner {
        daPlatform = platform;
        daPath = path;
        onchainMemoryThreshold = threshold;
        emit DaCheckpointSet(platform, path);
    }

    /// @dev Soumet la requête d'inférence au LLM 0x0802 (Phase 1) → jobId.
    ///      Encode la requête selon l'ABI officielle (skill ritual-dapp-llm) via
    ///      RitualLLM. Le prompt intègre la stratégie de l'agent, l'état de marché
    ///      (prix courant, prix précédent → tendance, position, capital) et des
    ///      règles de décision pro (trend-following / mean-reversion + gestion du
    ///      risque), inspirées des stratégies de trading classiques.
    function _submitLLM(address tee, uint256 price) internal returns (uint256 jobId, bytes memory ret) {
        // Contexte de marché : position et capital actuels de l'agent.
        uint256 pos = market.positionOf(agentId);
        uint256 cap = market.capitalOf(agentId);
        bool firstCycle = !strategyState.initialized;
        uint256 prevPrice = firstCycle ? price : strategyState.lastPrice;

        // System prompt : rôle + règles de décision propres à la stratégie +
        // gestion du risque + format de sortie STRICT (un seul mot). Court pour
        // limiter la taille du bytecode (la factory embarque ce contrat).
        string memory systemPrompt;
        if (agentStrategy == Strategy.TREND_FOLLOWING) {
            systemPrompt =
                "Trend. first=1,pos=0: BUY. Else up: BUY; down: SELL; flat: HOLD. Never oversell or buy without capital. Reply BUY/SELL/HOLD.";
        } else {
            systemPrompt =
                "Mean revert. first=1,pos=0: BUY. Else above prev: SELL; below: BUY; flat: HOLD. Never oversell or buy without capital. Reply BUY/SELL/HOLD.";
        }

        // User prompt : état de marché chiffré (prix en entier WAD 1e18).
        string memory userPrompt = string(
            abi.encodePacked(
                "price=",
                _toString(price),
                " prev=",
                _toString(prevPrice),
                " pos=",
                _toString(pos),
                " cap=",
                _toString(cap),
                " first=",
                firstCycle ? "1" : "0",
                ". Decide:"
            )
        );

        bytes memory messagesJson = bytes(RitualLLM.buildMessagesJson(systemPrompt, userPrompt));

        bytes memory request = RitualLLM.encodeRequest(
            tee, llmTtl, string(messagesJson), llmModel, llmMaxTokens
        );

        // jobId déterministe (indexation des events) — calculé AVANT l'appel pour pouvoir
        // retourner proprement en cas d'échec de commit.
        jobId = uint256(keccak256(abi.encodePacked(address(this), block.number, price)));

        bool ok;
        bytes memory raw;
        (ok, raw) = RitualAddresses.LLM_PRECOMPILE.call(request);
        if (!ok) {
            // SOFT-SKIP (fix autopilote) : échec de commit (ex. expéditeur momentanément
            // verrouillé par un async en vol) → on retourne une sortie VIDE sans revert.
            // L'appelant voit `ret` vide et termine le cycle proprement (pas de trade),
            // au lieu de gaspiller le gas planifié sur un revert.
            return (jobId, bytes(""));
        }

        // Déballer l'enveloppe async short-running : abi.encode(bytes simmedInput, bytes actualOutput).
        // En simulation/commitment `actualOutput` est VIDE ; sur le fulfilled-replay il contient la
        // vraie réponse LLM (skill ritual-dapp-llm + contrat oracle ritual-ta-oracle).
        (, ret) = abi.decode(raw, (bytes, bytes));
    }

    /// @dev Conversion uint256 → string décimale (pour le prompt).
    function _toString(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 temp = v;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (v != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(v % 10)));
            v /= 10;
        }
        return string(buffer);
    }

    /// @dev Solde disponible pour payer les fees d'appel (RitualWallet du wallet dédié).
    function _availableForFees() internal view returns (uint256) {
        // Le precompile LLM débite l'escrow de l'APPELANT (cet agent). Le garde-fou
        // doit donc vérifier le solde de CET agent dans le RitualWallet, pas celui
        // de l'AgentWallet.
        return IRitualWallet(RitualAddresses.RITUAL_WALLET).balanceOf(address(this));
    }

    // ─────────────────────────────────────────────────────────────────────
    // Lectures (Req 2.6)
    // ─────────────────────────────────────────────────────────────────────

    function availableCapital() external view returns (uint256) {
        return market.capitalOf(agentId);
    }

    function position() external view returns (uint256) {
        return market.positionOf(agentId);
    }

    function strategy() external view returns (Strategy) {
        return agentStrategy;
    }

    receive() external payable {}
}
