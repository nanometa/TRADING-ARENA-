"use client";

import { ConnectionGuard } from "@/components/ConnectionGuard";
import { AgentTable } from "@/components/AgentTable";

/// Page tableau des agents actifs (Req 8.4, 8.6).
export default function AgentsPage() {
  return (
    <ConnectionGuard>
      <div className="px-6 py-20">
        <h1 className="mb-12 font-display text-[14vw] uppercase leading-none tracking-tightest md:text-[7vw]">
          Agents
        </h1>
        <AgentTable />
      </div>
    </ConnectionGuard>
  );
}
