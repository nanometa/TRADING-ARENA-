"use client";

import { ConnectionGuard } from "@/components/ConnectionGuard";
import { LeaderboardTable } from "@/components/LeaderboardTable";

/// Page leaderboard temps réel (Req 8.8).
export default function LeaderboardPage() {
  return (
    <ConnectionGuard>
      <div className="px-6 py-20">
        <h1 className="mb-12 font-display text-[14vw] uppercase leading-none tracking-tightest md:text-[7vw]">
          Ranking
        </h1>
        <LeaderboardTable />
      </div>
    </ConnectionGuard>
  );
}
