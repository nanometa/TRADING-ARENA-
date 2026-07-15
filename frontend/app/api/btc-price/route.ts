import { NextResponse } from "next/server";

/// Proxy serveur pour le prix spot BTC/USD.
/// Source principale : Binance (ticker/price) — quotas très larges, pas de clé.
/// Secours : CoinGecko, puis dernière valeur connue. Format de sortie unifié
/// { bitcoin: { usd: number } } pour ne rien changer côté frontend.
export const dynamic = "force-dynamic";

let lastGood: { bitcoin: { usd: number } } | null = null;

export async function GET() {
  // 1) Binance.
  try {
    const res = await fetch(
      "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT",
      { cache: "no-store", signal: AbortSignal.timeout(5_000) },
    );
    if (!res.ok) throw new Error(`binance ${res.status}`);
    const data = (await res.json()) as { price: string };
    const out = { bitcoin: { usd: Math.round(Number(data.price)) } };
    lastGood = out;
    return NextResponse.json(out, {
      headers: { "Cache-Control": "public, s-maxage=15, stale-while-revalidate=30" },
    });
  } catch {
    // 2) Secours CoinGecko.
    try {
      const res = await fetch(
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd",
        { cache: "no-store", signal: AbortSignal.timeout(5_000) },
      );
      if (!res.ok) throw new Error(`coingecko ${res.status}`);
      const data = await res.json();
      lastGood = data;
      return NextResponse.json(data, {
        headers: { "Cache-Control": "public, s-maxage=15" },
      });
    } catch {
      // 3) Dernière valeur connue, sinon estimation neutre.
      return NextResponse.json(lastGood ?? { bitcoin: { usd: 60000 } }, {
        headers: { "Cache-Control": "no-store" },
      });
    }
  }
}
