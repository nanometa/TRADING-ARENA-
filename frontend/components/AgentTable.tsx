"use client";

import Link from "next/link";
import { formatEther } from "viem";
import { useAgents, type AgentView } from "@/lib/hooks/useAgents";
import { useAgentStats } from "@/lib/hooks/useAgentStats";

const STRATEGY_LABEL = ["trend following", "mean reversion"];
const STATUS_LABEL = ["active", "retired"];

/// Tableau des agents actifs avec performance courante en % (Req 8.4, 8.6).
export function AgentTable() {
  const { agents, isLoading, error, refetch } = useAgents();

  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (error)
    return (
      <div className="flex items-center gap-3 text-sm text-muted">
        <span>Agent data is temporarily unavailable.</span>
        <button
          type="button"
          onClick={() => void refetch()}
          className="border border-ink px-3 py-1 text-xs uppercase tracking-[0.12em] hover:bg-ink hover:text-paper"
        >
          Retry
        </button>
      </div>
    );
  if (agents.length === 0)
    return <p className="text-sm text-muted">No agents yet.</p>;

  return (
    <div className="overflow-x-auto border border-hairline">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-hairline text-xs uppercase tracking-[0.15em] text-muted">
          <tr>
            <th className="px-4 py-3">#</th>
            <th className="px-4 py-3">Agent</th>
            <th className="px-4 py-3">Strategy</th>
            <th className="px-4 py-3">Capital</th>
            <th className="px-4 py-3">Performance</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody>
          {agents.map((a, i) => (
            <AgentRow key={a.agent} agent={a} index={i} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function AgentRow({ agent, index }: { agent: AgentView; index: number }) {
  const { capital, pnl } = useAgentStats(BigInt(index), capitalBase(agent));

  return (
    <tr className="border-t border-hairline transition-colors duration-300 hover:bg-ink/[0.03]">
      <td className="px-4 py-3">{index}</td>
      <td className="px-4 py-3 font-mono text-xs">
        {agent.agent.slice(0, 8)}…{agent.agent.slice(-6)}
      </td>
      <td className="px-4 py-3 uppercase tracking-wide">{STRATEGY_LABEL[agent.strategy] ?? agent.strategy}</td>
      <td className="px-4 py-3">{Number(formatEther(capital)).toFixed(2)}</td>
      <td className="px-4 py-3">
        <span className={pnl >= 0 ? "text-ritualGreen" : "text-accent"}>
          {pnl >= 0 ? "+" : ""}
          {pnl.toFixed(2)}%
        </span>
      </td>
      <td className="px-4 py-3">
        <span className={agent.status === 0 ? "text-ritualGreen" : "text-muted"}>
          {STATUS_LABEL[agent.status] ?? agent.status}
        </span>
      </td>
      <td className="px-4 py-3">
        <Link
          href={`/agents/${index}`}
          className="border border-ink px-3 py-1 text-xs uppercase tracking-[0.12em] transition-colors duration-300 hover:bg-ink hover:text-paper"
        >
          View
        </Link>
      </td>
    </tr>
  );
}

function capitalBase(_agent: AgentView): bigint {
  // Base par défaut pour le calcul de performance (le détail affine).
  return 0n;
}
