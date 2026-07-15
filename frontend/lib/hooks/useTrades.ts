"use client";

import { useEffect, useState } from "react";
import { usePublicClient } from "wagmi";
import { parseAbiItem } from "viem";
import { ADDRESSES } from "@/lib/ritual";
import { sortTradesByBlockDesc } from "@/lib/validators";
import { IS_DEMO, makeDemoTrades } from "@/lib/demoData";

export interface TradeView {
  agentId: bigint;
  orderType: number; // 0 = buy, 1 = sell
  quantity: bigint;
  price: bigint;
  block: bigint;
}

const TRADE_EVENT = parseAbiItem(
  "event TradeExecuted(uint256 indexed agentId, uint8 orderType, uint256 quantity, uint256 price, uint256 blockNumber)",
);

/// Récupère les trades des 100 derniers blocs (Req 8.7), triés par bloc décroissant.
/// Rafraîchi toutes les 15 s.
export function useTrades() {
  const publicClient = usePublicClient();
  const [trades, setTrades] = useState<TradeView[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Mode démo (app pas encore déployée) : faux trades pour visualiser l'UI.
    if (IS_DEMO) {
      setTrades(sortTradesByBlockDesc(makeDemoTrades()));
      setIsLoading(false);
      return;
    }

    if (!publicClient) return;
    let cancelled = false;

    async function load() {
      try {
        const latest = await publicClient!.getBlockNumber();
        const fromBlock = latest > 100n ? latest - 100n : 0n;
        const logs = await publicClient!.getLogs({
          address: ADDRESSES.simpleMarket,
          event: TRADE_EVENT,
          fromBlock,
          toBlock: latest,
        });
        if (cancelled) return;
        const mapped: TradeView[] = logs.map((l) => ({
          agentId: l.args.agentId ?? 0n,
          orderType: Number(l.args.orderType ?? 0),
          quantity: l.args.quantity ?? 0n,
          price: l.args.price ?? 0n,
          block: l.args.blockNumber ?? l.blockNumber ?? 0n,
        }));
        setTrades(sortTradesByBlockDesc(mapped));
      } catch {
        if (!cancelled) setTrades([]);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    load();
    const id = setInterval(load, 15_000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, [publicClient]);

  return { trades, isLoading };
}
