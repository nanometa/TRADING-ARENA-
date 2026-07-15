"use client";

import { useEffect, useState } from "react";

export interface PricePoint {
  time: number; // timestamp en secondes (UTC)
  value: number; // prix USD
}
export interface VolumePoint {
  time: number;
  value: number;
}

/// Récupère l'historique BTC/USD (prix + volume) sur N jours via CoinGecko
/// `market_chart` (gratuit). Utilisé pour le chart "style CoinMarketCap".
/// Rafraîchi toutes les 60 s.
export function useBtcMarketChart(days = 1) {
  const [prices, setPrices] = useState<PricePoint[]>([]);
  const [volumes, setVolumes] = useState<VolumePoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const url = `/api/btc-chart?days=${days}`;
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();

        // CoinGecko renvoie [ [ms, value], ... ]. lightweight-charts veut des
        // secondes croissantes et uniques.
        const dedupe = (arr: [number, number][]): { time: number; value: number }[] => {
          const seen = new Set<number>();
          const out: { time: number; value: number }[] = [];
          for (const [ms, v] of arr) {
            const t = Math.floor(ms / 1000);
            if (seen.has(t)) continue;
            seen.add(t);
            out.push({ time: t, value: v });
          }
          return out.sort((a, b) => a.time - b.time);
        };

        if (cancelled) return;
        setPrices(dedupe(data.prices ?? []));
        setVolumes(dedupe(data.total_volumes ?? []));
        setError(null);
      } catch (e) {
        if (!cancelled) setError((e as Error).message);
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    load();
    const id = setInterval(load, 60_000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, [days]);

  return { prices, volumes, isLoading, error };
}
