"use client";

import { useReadContract } from "wagmi";
import { ADDRESSES } from "@/lib/ritual";
import { leaderboardAbi } from "@/lib/abis";
import { IS_DEMO, makeDemoLeaderboard } from "@/lib/demoData";

export interface LeaderboardRow {
  rank: number;
  agentId: bigint;
  score: bigint;
}

/// Lit le classement depuis le Leaderboard_Contract, rafraîchi ≤ 15 s (Req 8.8).
/// En mode démo (app pas déployée), retourne un classement factice cohérent.
export function useLeaderboard() {
  const { data, isLoading, error } = useReadContract({
    address: ADDRESSES.leaderboard,
    abi: leaderboardAbi,
    functionName: "ranking",
    query: { refetchInterval: 15_000, enabled: !IS_DEMO },
  });

  if (IS_DEMO) {
    return { rows: makeDemoLeaderboard(), isLoading: false, error: null };
  }

  const rows: LeaderboardRow[] = [];
  if (data) {
    const [ids, scores] = data as [bigint[], bigint[]];
    for (let i = 0; i < ids.length; i++) {
      rows.push({ rank: i + 1, agentId: ids[i], score: scores[i] });
    }
  }

  return { rows, isLoading, error };
}
