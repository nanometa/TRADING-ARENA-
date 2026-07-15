"use client";

import { useReadContract } from "wagmi";
import { ADDRESSES } from "@/lib/ritual";
import { agentFactoryAbi } from "@/lib/abis";
import { IS_DEMO, makeDemoAgents } from "@/lib/demoData";

export interface AgentView {
  agent: `0x${string}`;
  owner: `0x${string}`;
  wallet: `0x${string}`;
  strategy: number; // 0 = trend-following, 1 = mean-reversion
  status: number; // 0 = active, 1 = retired
}

/// Lit la liste des agents depuis l'AgentFactory, rafraîchie toutes les 15 s (Req 8.3).
/// En mode démo (app pas déployée), retourne 3 agents factices.
export function useAgents() {
  const { data, isLoading, error, refetch } = useReadContract({
    address: ADDRESSES.agentFactory,
    abi: agentFactoryAbi,
    functionName: "listAgents",
    query: { refetchInterval: 15_000, enabled: !IS_DEMO },
  });

  if (IS_DEMO) {
    const demo = makeDemoAgents();
    return {
      agents: demo,
      activeCount: demo.filter((a) => a.status === 0).length,
      isLoading: false,
      error: null,
      refetch: () => {},
    };
  }

  const agents = (data as AgentView[] | undefined) ?? [];
  const activeCount = agents.filter((a) => a.status === 0).length;

  return { agents, activeCount, isLoading, error, refetch };
}
