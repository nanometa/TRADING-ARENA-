"use client";

import dynamic from "next/dynamic";
import { ConnectionGuard } from "@/components/ConnectionGuard";
import { TradeTable } from "@/components/TradeTable";
import { useTrades } from "@/lib/hooks/useTrades";

// Chargement paresseux du chart (lightweight-charts ~50 kB) : il n'est récupéré
// que sur cette page, après le rendu initial. Allège le 1er chargement.
const BtcLiveChart = dynamic(
  () => import("@/components/BtcLiveChart").then((m) => m.BtcLiveChart),
  {
    ssr: false,
    loading: () => (
      <div className="flex h-[420px] items-center justify-center border border-hairline">
        <span className="text-sm text-muted">Loading chart…</span>
      </div>
    ),
  },
);

/// Page Trades : UN SEUL chart BTC/USD live (marché réel) sur lequel sont
/// superposés les trades des agents (marqueurs achat/vente), puis le tableau.
export default function TradesPage() {
  const { trades, isLoading } = useTrades();

  return (
    <ConnectionGuard>
      <div className="px-6 py-20">
        <h1 className="mb-12 font-display text-[14vw] uppercase leading-none tracking-tightest md:text-[7vw]">
          Trades
        </h1>

        {/* Chart unique : BTC/USD live + marqueurs des trades des agents */}
        <div className="mb-12">
          <BtcLiveChart trades={trades} />
        </div>

        {/* Tableau détaillé des trades on-chain */}
        <h2 className="mb-4 text-[11px] uppercase tracking-[0.35em] text-muted">
          Trade Details On Chain
        </h2>
        <TradeTable trades={trades} isLoading={isLoading} />
      </div>
    </ConnectionGuard>
  );
}
