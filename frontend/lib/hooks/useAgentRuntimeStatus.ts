"use client";

import { useReadContracts } from "wagmi";
import { zeroAddress } from "viem";
import { ritualWalletAbi, tradingAgentAbi } from "@/lib/abis";
import { SYSTEM_ADDRESSES } from "@/lib/ritual";

export function useAgentRuntimeStatus(agentAddress: `0x${string}`) {
  const enabled = agentAddress !== zeroAddress;

  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      { address: agentAddress, abi: tradingAgentAbi, functionName: "paused" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "callId" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "scheduleFrequency" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "scheduleNumCalls" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "scheduleTtl" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "autoReschedule" },
      { address: agentAddress, abi: tradingAgentAbi, functionName: "consecutiveLlmErrors" },
      {
        address: agentAddress,
        abi: tradingAgentAbi,
        functionName: "cachedExecutor",
        args: [1],
      },
      {
        address: SYSTEM_ADDRESSES.ritualWallet,
        abi: ritualWalletAbi,
        functionName: "balanceOf",
        args: [agentAddress],
      },
    ] as const,
    query: { enabled, refetchInterval: 10_000 },
  });

  const value = <T,>(index: number, fallback: T) =>
    data?.[index]?.status === "success" ? (data[index].result as T) : fallback;
  const hasLlmErrorCounter = data?.[6]?.status === "success";

  return {
    paused: value(0, true),
    callId: value(1, 0n),
    frequency: Number(value(2, 0)),
    numCalls: Number(value(3, 0)),
    ttl: Number(value(4, 0)),
    autoReschedule: value(5, false),
    consecutiveLlmErrors: hasLlmErrorCounter ? Number(value(6, 0)) : null,
    supportsLlmErrorCounter: hasLlmErrorCounter,
    llmExecutor: value(7, zeroAddress) as `0x${string}`,
    feeEscrow: value(8, 0n),
    isLoading,
    error,
    refetch,
  };
}
