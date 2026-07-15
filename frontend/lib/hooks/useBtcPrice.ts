"use client";

import { useEffect, useState } from "react";

/// Récupère le vrai prix BTC/USD live (CoinGecko) pour AFFICHAGE sur le dashboard.
/// C'est la même source que celle utilisée on-chain par les agents (via le HTTP
/// precompile de Ritual) — ici en lecture directe côté frontend, juste pour l'UI.
/// Rafraîchi toutes les 30 s.
export function useBtcPrice() {
  const [price, setPrice] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const res = await fetch("/api/btc-price", { cache: "no-store" });
        const data = await res.json();
        const p = data?.bitcoin?.usd;
        if (!cancelled && typeof p === "number") {
          setPrice(p);
        }
      } catch {
        // réseau indisponible → on garde la dernière valeur connue
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    load();
    const id = setInterval(load, 30_000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, []);

  return { price, isLoading };
}
