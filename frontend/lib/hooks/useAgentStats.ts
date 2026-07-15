"use client";

import { useReadContracts } from "wagmi";
import { formatEther } from "viem";
import { ADDRESSES } from "@/lib/ritual";
import { simpleMarketAbi } from "@/lib/abis";
import { performancePercent } from "@/lib/validators";

/// Lit capital + position + prix courant d'un agent et calcule le pnl% live
/// (Req 8.6, Property 24). La valeur du portefeuille = capital + position × prix.
export function useAgentStats(agentId: bigint, initialCapital: bigint) {
  const { data, isLoading } = useReadContracts({
    contracts: [
      {
        address: ADDRESSES.simpleMarket,
        abi: simpleMarketAbi,
        functionName: "capitalOf",
        args: [agentId],
      },
      {
        address: ADDRESSES.simpleMarket,
        abi: simpleMarketAbi,
        functionName: "positionOf",
        args: [agentId],
      },
      {
        address: ADDRESSES.simpleMarket,
        abi: simpleMarketAbi,
        functionName: "currentPrice",
      },
    ],
    query: { refetchInterval: 15_000 },
  });

  const capital = (data?.[0]?.result as bigint | undefined) ?? 0n;
  const position = (data?.[1]?.result as bigint | undefined) ?? 0n;
  const price = (data?.[2]?.result as bigint | undefined) ?? 0n;

  // Valeur du portefeuille en nombre flottant (RITUAL).
  const portfolioValue =
    Number(formatEther(capital)) +
    Number(formatEther(position)) * Number(formatEther(price));
  const initial = Number(formatEther(initialCapital));
  const pnl = performancePercent(portfolioValue, initial);

  return { capital, position, price, portfolioValue, pnl, isLoading };
}
