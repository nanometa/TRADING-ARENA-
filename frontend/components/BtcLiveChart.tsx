"use client";

import { useEffect, useRef, useState } from "react";
import {
  createChart,
  ColorType,
  type IChartApi,
  type ISeriesApi,
} from "lightweight-charts";
import { useBtcMarketChart } from "@/lib/hooks/useBtcMarketChart";
import type { TradeView } from "@/lib/hooks/useTrades";

const RANGES = [
  { label: "24H", days: 1 },
  { label: "7D", days: 7 },
  { label: "30D", days: 30 },
];

/// Chart BTC/USD live "style CoinMarketCap" : aire de prix + histogramme de volume,
/// rendu avec lightweight-charts (TradingView). Données réelles via CoinGecko.
/// Les trades des agents (achat/vente) sont superposés en MARQUEURS sur la courbe.
/// Palette Ritual : fond noir, ligne verte, volume orange discret.
export function BtcLiveChart({ trades = [] }: { trades?: TradeView[] }) {
  const [days, setDays] = useState(1);
  const { prices, volumes, isLoading, error } = useBtcMarketChart(days);

  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<IChartApi | null>(null);
  const areaRef = useRef<ISeriesApi<"Area"> | null>(null);
  const volRef = useRef<ISeriesApi<"Histogram"> | null>(null);

  // Création du chart (une fois).
  useEffect(() => {
    if (!containerRef.current) return;

    const chart = createChart(containerRef.current, {
      layout: {
        background: { type: ColorType.Solid, color: "transparent" },
        textColor: "#8a8a8a",
        fontFamily: "Archivo, sans-serif",
      },
      grid: {
        vertLines: { color: "rgba(255,255,255,0.04)" },
        horzLines: { color: "rgba(255,255,255,0.04)" },
      },
      rightPriceScale: { borderColor: "rgba(255,255,255,0.14)" },
      timeScale: {
        borderColor: "rgba(255,255,255,0.14)",
        timeVisible: true,
        secondsVisible: false,
      },
      crosshair: {
        vertLine: { color: "#ff5c00", labelBackgroundColor: "#ff5c00" },
        horzLine: { color: "#ff5c00", labelBackgroundColor: "#ff5c00" },
      },
      // Chart FIXE : pas de zoom/déplacement avec la souris ni le scroll.
      handleScroll: false,
      handleScale: false,
      kineticScroll: { mouse: false, touch: false },
      height: 360,
      autoSize: true,
    });

    // Verrouille aussi l'échelle de temps et de prix (pas de drag manuel).
    chart.timeScale().applyOptions({
      lockVisibleTimeRangeOnResize: true,
      rightOffset: 0,
      fixLeftEdge: true,
      fixRightEdge: true,
    });

    const area = chart.addAreaSeries({
      lineColor: "#3fe0a8",
      topColor: "rgba(63,224,168,0.28)",
      bottomColor: "rgba(63,224,168,0.0)",
      lineWidth: 2,
      priceFormat: { type: "price", precision: 0, minMove: 1 },
    });

    const vol = chart.addHistogramSeries({
      color: "rgba(255,92,0,0.45)",
      priceFormat: { type: "volume" },
      priceScaleId: "vol",
    });
    // Volume confiné en bas (20% de hauteur).
    chart.priceScale("vol").applyOptions({
      scaleMargins: { top: 0.8, bottom: 0 },
    });

    chartRef.current = chart;
    areaRef.current = area;
    volRef.current = vol;

    return () => {
      chart.remove();
      chartRef.current = null;
      areaRef.current = null;
      volRef.current = null;
    };
  }, []);

  // Mise à jour des données.
  useEffect(() => {
    if (!areaRef.current || !volRef.current) return;
    if (prices.length === 0) return;

    areaRef.current.setData(
      prices.map((p) => ({ time: p.time as never, value: p.value })),
    );
    volRef.current.setData(
      volumes.map((v) => ({ time: v.time as never, value: v.value })),
    );

    // Superposer les trades des agents en MARQUEURS sur la courbe de prix.
    // Les trades sont identifiés par bloc (pas de timestamp) : on les répartit
    // régulièrement sur la fenêtre temporelle visible pour les visualiser.
    if (trades.length > 0 && prices.length > 1) {
      const t0 = prices[0].time;
      const t1 = prices[prices.length - 1].time;
      const ordered = [...trades].sort((a, b) =>
        a.block < b.block ? -1 : a.block > b.block ? 1 : 0,
      );
      const n = ordered.length;
      const markers = ordered.map((tr, i) => {
        const time = Math.floor(t0 + ((t1 - t0) * i) / Math.max(1, n - 1));
        const buy = tr.orderType === 0;
        return {
          time: time as never,
          position: (buy ? "belowBar" : "aboveBar") as "belowBar" | "aboveBar",
          color: buy ? "#3fe0a8" : "#ff2d2d",
          shape: (buy ? "arrowUp" : "arrowDown") as "arrowUp" | "arrowDown",
          text: buy ? "B" : "S",
        };
      });
      const seen = new Set<number>();
      const uniq = markers.filter((m) => {
        const t = m.time as unknown as number;
        if (seen.has(t)) return false;
        seen.add(t);
        return true;
      });
      areaRef.current.setMarkers(uniq);
    } else {
      areaRef.current.setMarkers([]);
    }

    chartRef.current?.timeScale().fitContent();
  }, [prices, volumes, trades]);

  const last = prices.length > 0 ? prices[prices.length - 1].value : null;
  const first = prices.length > 0 ? prices[0].value : null;
  const changePct =
    last && first ? ((last - first) / first) * 100 : null;
  const up = (changePct ?? 0) >= 0;

  return (
    <div className="border border-hairline p-4">
      <div className="mb-4 flex flex-wrap items-baseline justify-between gap-3">
        <div className="flex items-baseline gap-4">
          <span className="text-[11px] uppercase tracking-[0.25em] text-muted">
            BTC USD LIVE
          </span>
          {last && (
            <span className="font-display text-3xl tracking-tightest text-ink">
              ${last.toLocaleString("en-US", { maximumFractionDigits: 0 })}
            </span>
          )}
          {changePct !== null && (
            <span
              className="text-sm font-medium"
              style={{ color: up ? "#3fe0a8" : "#ff5c00" }}
            >
              {up ? "▲" : "▼"} {Math.abs(changePct).toFixed(2)}%
            </span>
          )}
        </div>

        {/* Sélecteur de période */}
        <div className="flex gap-1">
          {RANGES.map((r) => (
            <button
              key={r.days}
              onClick={() => setDays(r.days)}
              className={`px-3 py-1 text-[10px] uppercase tracking-[0.15em] transition-colors ${
                days === r.days
                  ? "bg-ink text-paper"
                  : "text-muted hover:text-ink"
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      <div ref={containerRef} className="h-[360px] w-full" />

      {/* Légende des marqueurs de trades des agents */}
      {trades.length > 0 && (
        <div className="mt-3 flex gap-6 text-[10px] uppercase tracking-[0.2em] text-muted">
          <span className="flex items-center gap-2">
            <span className="text-ritualGreen">▲</span> Agent Buy
          </span>
          <span className="flex items-center gap-2">
            <span style={{ color: "#ff2d2d" }}>▼</span> Agent Sell
          </span>
          <span className="ml-auto">{trades.length} on chain trades</span>
        </div>
      )}

      {isLoading && prices.length === 0 && (
        <p className="mt-3 text-sm text-muted">Loading market…</p>
      )}
      {error && (
        <p className="mt-3 text-sm text-accent">
          Market unavailable ({error}). Retrying automatically.
        </p>
      )}
    </div>
  );
}
