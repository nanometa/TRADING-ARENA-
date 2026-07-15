// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AgentFactory} from "../src/AgentFactory.sol";
import {TradingAgent} from "../src/TradingAgent.sol";
import {AgentRecord} from "../src/interfaces/IArena.sol";
import {Strategy} from "../src/interfaces/IRitualSystem.sol";

/// @title SeedDemoAgents
/// @notice Crée 1 à 5 agents de démonstration (Req 10.2, 10.3, 10.4), chacun avec
///         un Agent_Wallet distinct et une Strategy assignée, puis approvisionne
///         chaque TradingAgent avec le verrouillage de dépôt requis AVANT d'activer les
///         exécutions planifiées (Req 10.7).
///
/// @dev Le plafond de 5 est appliqué par la factory (Req 10.3) ; un déploiement
///      avec moins de 3 agents reste autorisé (Req 10.4).
///
/// ─────────────────────────────────────────────────────────────────────────
/// PRESET "1 RITUAL — démo réactive et plafonnée"
/// ─────────────────────────────────────────────────────────────────────────
/// Objectif : démo vivante (cycle ~1 min au lieu de ~12 min) tout en GARANTISSANT
/// que le budget total ne dépasse jamais le faucet. Deux protections cumulées :
///
///  1) Plafond PHYSIQUE = le dépôt. Le RitualWallet ne débite les frais qu'à
///     l'EXÉCUTION ; si le solde est insuffisant, le cycle est *sauté*, pas l'agent
///     supprimé (skill scheduler : "execution is skipped, not cancelled"). Donc un
///     agent ne peut JAMAIS dépenser plus que son dépôt verrouillé.
///  2) Plafond LOGIQUE = setBudgetLimit (budget glissant on-chain, Req 9.1/9.2) :
///     borne en plus le capital *engagé en trades* sur une fenêtre temporelle.
///
/// Timing (baseline officielle ~0,35 s/bloc, skill ritual-dapp-block-time) :
///   FREQUENCY=170 → ~1 min entre cycles (au lieu de 2000 → ~11,7 min).
///   TTL=300       → ~105 s, couvre le settlement LLM (raisonnement 10-40 s) — clé !
///   NUM_CALLS=1   → série one-shot fiable ; l'agent se replanifie seulement s'il
///                   reste sain et suffisamment financé.
///
/// Budget pour 1 RITUAL réparti sur N agents (N ≤ 5) :
///   DEPOSIT_PER_AGENT = floor((BUDGET_TOTAL - marge_gas) / N).
///   Par défaut : un agent avec BUDGET_TOTAL=0,4 RITUAL.
///
/// Variables d'environnement (toutes optionnelles, défauts = preset 1 RITUAL) :
///   FACTORY_ADDRESS   — adresse de l'AgentFactory déployée (REQUISE)
///   DEMO_COUNT        — nombre d'agents (1..5), défaut 1
///   BUDGET_TOTAL      — budget natif total à répartir (wei), défaut 0,4 ether
///   DEPOSIT_PER_AGENT — override explicite du dépôt par agent (wei) ; sinon calculé
///   LOCK_DURATION     — verrouillage en blocs, défaut 10000
///   FREQUENCY         — blocs entre cycles, défaut 170 (~1 min)
///   NUM_CALLS         — appels par série, défaut 1
///   TTL               — fenêtre d'exécution en blocs, défaut 300 (couvre settlement LLM)
///
/// Usage :
///   FACTORY_ADDRESS=0x... forge script script/SeedDemoAgents.s.sol:SeedDemoAgents \
///     --rpc-url https://rpc.ritualfoundation.org --private-key $PRIVATE_KEY --broadcast
contract SeedDemoAgents is Script {
    uint256 internal constant DEMO_CAPITAL = 1_000e18;

    function run() external {
        address factoryAddr = vm.envAddress("FACTORY_ADDRESS");

        uint256 demoCount = vm.envOr("DEMO_COUNT", uint256(1));
        require(demoCount >= 1 && demoCount <= 5, "DEMO_COUNT doit etre dans [1,5]");

        // Budget total à répartir (plafond dur via les dépôts).
        uint256 budgetTotal = vm.envOr("BUDGET_TOTAL", uint256(0.4 ether));
        // Dépôt par agent : explicite si fourni, sinon réparti équitablement.
        uint256 depositPerAgent = vm.envOr("DEPOSIT_PER_AGENT", budgetTotal / demoCount);
        require(depositPerAgent > 0, "DEPOSIT_PER_AGENT nul");

        uint256 lockDuration = vm.envOr("LOCK_DURATION", uint256(200_000));

        // Le Scheduler est configuré avec payer=TradingAgent et le LLM est appelé
        // par ce même TradingAgent. Un escrow unique sur l'agent paie donc les deux.
        require(depositPerAgent >= 0.35 ether, "depot LLM < 0.35 RITUAL");

        // Timing réactif : ~1 min/cycle, TTL couvrant le settlement LLM.
        uint32 frequency = uint32(vm.envOr("FREQUENCY", uint256(170)));
        uint32 numCalls = uint32(vm.envOr("NUM_CALLS", uint256(1)));
        uint32 ttl = uint32(vm.envOr("TTL", uint256(300)));

        // Garde-fou : respecter MAX_LIFESPAN (frequency × numCalls ≤ 10 000).
        require(uint256(frequency) * uint256(numCalls) <= 10_000, "lifespan > 10000");
        require(ttl >= 1 && ttl <= 500, "ttl hors [1,500]");

        // Budget glissant on-chain (2e protection) : borne le capital engagé en trades
        // par fenêtre. Fenêtre ~ frequency × numCalls blocs convertis en secondes.
        uint256 budgetWindowSeconds = vm.envOr("BUDGET_WINDOW_SECONDS", uint256(3600));
        // Limite d'engagement par fenêtre, en unités de capital interne (mark-to-market).
        uint256 budgetLimit = vm.envOr("BUDGET_LIMIT", DEMO_CAPITAL / 2);

        // Exécuteurs TEE (0=HTTP, 1=LLM) — à découvrir hors-chaîne via
        // getServicesByCapability(cap,true). Optionnels : si non fournis, l'agent
        // tentera la découverte on-chain au 1er cycle (plus coûteux en gaz).
        address httpExec = vm.envOr("HTTP_EXECUTOR", address(0));
        address llmExec = vm.envOr("LLM_EXECUTOR", address(0));

        AgentFactory factory = AgentFactory(factoryAddr);

        vm.startBroadcast();

        for (uint256 i = 0; i < demoCount; i++) {
            // Alterner les stratégies (Req 10.2).
            Strategy strat = (i % 2 == 0)
                ? Strategy.TREND_FOLLOWING
                : Strategy.MEAN_REVERSION;

            uint256 agentId = factory.createDemoAgent(strat, DEMO_CAPITAL);
            AgentRecord memory rec = factory.getAgent(agentId);

            TradingAgent agent = TradingAgent(payable(rec.agent));

            // 1) Escrow unique du TradingAgent : paie Scheduler + LLM.
            agent.fundFees{value: depositPerAgent}(lockDuration);

            // 2) Enregistrer le bloc d'expiration du verrou côté agent (garde-fou Req 2.4).
            agent.recordDepositLock(block.number + lockDuration);

            // 3) Plafond LOGIQUE supplémentaire : budget glissant (Req 9.1).
            agent.setBudgetLimit(budgetLimit, budgetWindowSeconds);

            // 3b) Câbler l'exécuteur LLM avant activation. HTTP reste optionnel.
            if (httpExec != address(0)) agent.setExecutor(0, httpExec);
            if (llmExec != address(0)) agent.setExecutor(1, llmExec);

            // 4) Activer la planification autonome (Req 4.1) — sauf si ACTIVATE=false
            //    (alors on active séparément APRÈS setExecutor + setPricePair, requis
            //    pour un test contrôlé sans planification automatique).
            if (vm.envOr("ACTIVATE", true)) {
                agent.activate(frequency, numCalls, ttl);
            }

            console2.log("Agent de demo cree + active :");
            console2.log("  agentId :", agentId);
            console2.log("  agent   :", rec.agent);
            console2.log("  wallet  :", rec.wallet);
            console2.log("  strategy:", uint256(uint8(strat)));
            console2.log("  depot (plafond dur, wei):", depositPerAgent);
        }

        vm.stopBroadcast();

        console2.log("Total agents de demo :", demoCount);
        console2.log("Depot total verrouille (wei):", depositPerAgent * demoCount);
        console2.log("Cycle approx (s) = frequency * 0.35:", uint256(frequency) * 35 / 100);
    }
}
