"use client";

import { useParams } from "next/navigation";
import { useAccount } from "wagmi";
import { formatEther } from "viem";
import { ConnectionGuard } from "@/components/ConnectionGuard";
import { useAgents } from "@/lib/hooks/useAgents";
import { useAgentStats } from "@/lib/hooks/useAgentStats";
import { useAgentControls } from "@/lib/hooks/useAgentControls";
import { useAgentRuntimeStatus } from "@/lib/hooks/useAgentRuntimeStatus";
import { TxErrorToast } from "@/components/TxErrorToast";

const STRATEGY_LABEL = ["Trend Following", "Mean Reversion"];

/// Page détail d'un agent : stats live + contrôles owner (Req 9.3–9.7).
export default function AgentDetailPage() {
  const params = useParams();
  const id = BigInt((params?.id as string) ?? "0");
  const index = Number(id);

  const { address } = useAccount();
  const { agents } = useAgents();
  const agent = agents[index];

  const { capital, position, price, portfolioValue, pnl } = useAgentStats(id, 0n);
  const controls = useAgentControls(
    (agent?.agent ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  );
  const runtime = useAgentRuntimeStatus(
    (agent?.agent ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  );

  const isOwner =
    !!address && !!agent && address.toLowerCase() === agent.owner.toLowerCase();

  return (
    <ConnectionGuard>
      <h1 className="mb-2 text-2xl font-bold">Agent #{index}</h1>

      {!agent ? (
        <p className="text-sm text-muted">Agent not found.</p>
      ) : (
        <>
          <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-2">
            <Info label="Address" value={agent.agent} mono />
            <Info label="Owner" value={agent.owner} mono />
            <Info
              label="Strategy"
              value={STRATEGY_LABEL[agent.strategy] ?? String(agent.strategy)}
            />
            <Info label="Status" value={agent.status === 0 ? "active" : "retired"} />
            <Info label="Autopilot" value={runtime.paused ? "paused" : "running"} />
            <Info
              label="Execution Mode"
              value={runtime.autoReschedule ? "continuous" : "protected one-shot"}
            />
            <Info label="Schedule Call ID" value={runtime.callId.toString()} mono />
            <Info
              label="Schedule"
              value={`${runtime.numCalls} call(s) · every ${runtime.frequency} blocks · TTL ${runtime.ttl}`}
            />
            <Info label="Execution Node" value={runtime.llmExecutor} mono />
            <Info
              label="Agent Fee Escrow"
              value={`${Number(formatEther(runtime.feeEscrow)).toFixed(6)} RITUAL`}
            />
            <Info label="Capital" value={`${Number(formatEther(capital)).toFixed(2)} RITUAL`} />
            <Info label="Position" value={Number(formatEther(position)).toFixed(2)} />
            <Info label="Current Price" value={Number(formatEther(price)).toFixed(4)} />
            <Info
              label="Portfolio Value"
              value={`${portfolioValue.toFixed(2)} (${pnl >= 0 ? "+" : ""}${pnl.toFixed(2)}%)`}
            />
          </div>

          <h2 className="mb-3 text-lg font-semibold">Owner Controls</h2>
          {!isOwner ? (
            <p className="text-sm text-muted">
              Connect with the owner wallet to manage this agent.
            </p>
          ) : (
            <div className="flex flex-wrap gap-2">
              <Btn onClick={controls.pause} disabled={controls.isPending}>
                Pause
              </Btn>
              <Btn onClick={controls.resume} disabled={controls.isPending}>
                Resume
              </Btn>
              <Btn onClick={controls.requestPrice} disabled={controls.isPending}>
                Refresh Price HTTP
              </Btn>
              <Btn onClick={controls.emergencyStop} disabled={controls.isPending} danger>
                Emergency Stop
              </Btn>
              <Btn onClick={controls.emergencyWithdraw} disabled={controls.isPending} danger>
                Emergency Withdraw
              </Btn>
            </div>
          )}
          <TxErrorToast message={controls.error} />
        </>
      )}
    </ConnectionGuard>
  );
}

function Info({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="rounded border border-border bg-panel p-3">
      <p className="text-xs text-muted">{label}</p>
      <p className={`mt-1 ${mono ? "break-all font-mono text-xs" : "text-sm"}`}>{value}</p>
    </div>
  );
}

function Btn({
  children,
  onClick,
  disabled,
  danger,
}: {
  children: React.ReactNode;
  onClick: () => void;
  disabled?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`rounded px-3 py-2 text-xs font-semibold disabled:opacity-50 ${
        danger ? "bg-danger text-black" : "bg-accent text-white"
      }`}
    >
      {children}
    </button>
  );
}
