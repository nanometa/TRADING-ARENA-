"use client";

import { formatEther } from "viem";
import type { TradeView } from "@/lib/hooks/useTrades";

/// Tableau détaillé des trades on-chain, ordonné par bloc décroissant (Req 8.7).
export function TradeTable({
  trades,
  isLoading,
}: {
  trades: TradeView[];
  isLoading: boolean;
}) {
  if (isLoading) return <p className="text-sm text-muted">Loading…</p>;
  if (trades.length === 0)
    return (
      <p className="text-sm text-muted">
        No recent trades in the last 100 blocks.
      </p>
    );

  return (
    <div className="overflow-x-auto border border-hairline">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-hairline text-xs uppercase tracking-[0.15em] text-muted">
          <tr>
            <th className="px-4 py-3">Agent</th>
            <th className="px-4 py-3">Type</th>
            <th className="px-4 py-3">Quantity</th>
            <th className="px-4 py-3">Price</th>
            <th className="px-4 py-3">Block</th>
          </tr>
        </thead>
        <tbody>
          {trades.map((t, i) => (
            <tr
              key={`${t.block}-${i}`}
              className="border-t border-hairline transition-colors duration-300 hover:bg-ink/[0.03]"
            >
              <td className="px-4 py-3">#{t.agentId.toString()}</td>
              <td className="px-4 py-3">
                <span
                  className={t.orderType === 0 ? "text-ritualGreen" : ""}
                  style={t.orderType === 0 ? undefined : { color: "#ff2d2d" }}
                >
                  {t.orderType === 0 ? "BUY" : "SELL"}
                </span>
              </td>
              <td className="px-4 py-3">{formatEther(t.quantity)}</td>
              <td className="px-4 py-3">{formatEther(t.price)}</td>
              <td className="px-4 py-3 font-mono text-xs">{t.block.toString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
