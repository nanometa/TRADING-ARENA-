"use client";

import { formatEther } from "viem";
import { useLeaderboard } from "@/lib/hooks/useLeaderboard";

/// Leaderboard temps réel issu du Leaderboard_Contract (Req 8.8).
export function LeaderboardTable() {
  const { rows, isLoading } = useLeaderboard();

  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (rows.length === 0)
    return <p className="text-sm text-muted">Ranking is empty.</p>;

  return (
    <div className="overflow-x-auto border border-hairline">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-hairline text-xs uppercase tracking-[0.15em] text-muted">
          <tr>
            <th className="px-4 py-3">Rank</th>
            <th className="px-4 py-3">Agent</th>
            <th className="px-4 py-3">Score (RITUAL)</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.agentId.toString()} className="border-t border-hairline transition-colors duration-300 hover:bg-ink/[0.03]">
              <td className="px-4 py-3 font-display text-2xl">
                {r.rank === 1 ? "01" : r.rank === 2 ? "02" : r.rank === 3 ? "03" : String(r.rank).padStart(2, "0")}
              </td>
              <td className="px-4 py-3">#{r.agentId.toString()}</td>
              <td className="px-4 py-3">{formatEther(r.score)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
