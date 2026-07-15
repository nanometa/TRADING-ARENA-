import { parseEther } from "viem";
import type { TradeView } from "@/lib/hooks/useTrades";
import { ADDRESSES } from "@/lib/ritual";

/// Vrai si l'app n'est pas encore déployée (adresses à zéro). Dans ce cas, on
/// affiche des données de DÉMO pour visualiser l'UI (chart, tableaux) avant le
/// déploiement. Dès que les NEXT_PUBLIC_* sont renseignées, on lit la vraie chaîne.
export const IS_DEMO =
  ADDRESSES.simpleMarket ===
  "0x0000000000000000000000000000000000000000";

/// Génère une série de faux trades cohérente : prix qui évolue façon marché
/// (marche aléatoire bornée), achats/ventes alternés sur quelques agents.
/// Déterministe (même rendu à chaque appel) pour éviter le scintillement.
export function makeDemoTrades(count = 40): TradeView[] {
  const trades: TradeView[] = [];
  let price = 1.0;
  let seed = 12345;
  // PRNG simple déterministe (mulberry32-like).
  const rand = () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  const startBlock = 1_000_000;
  for (let i = 0; i < count; i++) {
    // Variation de prix ~ ±2,5%.
    const drift = (rand() - 0.48) * 0.05;
    price = Math.max(0.2, price * (1 + drift));
    const orderType = drift >= 0 ? 0 : 1; // hausse → achat, baisse → vente
    const agentId = BigInt((i % 3) + 1);
    trades.push({
      agentId,
      orderType,
      quantity: parseEther((50 + Math.floor(rand() * 100)).toString()),
      price: parseEther(price.toFixed(6)),
      block: BigInt(startBlock + i * 170),
    });
  }
  // Ordre décroissant (comme la vraie source on-chain).
  return trades.reverse();
}

import type { AgentView } from "@/lib/hooks/useAgents";
import type { LeaderboardRow } from "@/lib/hooks/useLeaderboard";

/// 3 agents de démo (2 trend-following, 1 mean-reversion), tous actifs.
export function makeDemoAgents(): AgentView[] {
  const mk = (n: number, strategy: number): AgentView => ({
    agent: `0x${"a".repeat(39)}${n}` as `0x${string}`,
    owner: `0x${"b".repeat(39)}${n}` as `0x${string}`,
    wallet: `0x${"c".repeat(39)}${n}` as `0x${string}`,
    strategy,
    status: 0, // actif
  });
  return [mk(1, 0), mk(2, 1), mk(3, 0)];
}

/// Classement de démo, cohérent avec les 3 agents (scores décroissants).
export function makeDemoLeaderboard(): LeaderboardRow[] {
  return [
    { rank: 1, agentId: 2n, score: parseEther("1180") },
    { rank: 2, agentId: 1n, score: parseEther("1045") },
    { rank: 3, agentId: 3n, score: parseEther("960") },
  ];
}
