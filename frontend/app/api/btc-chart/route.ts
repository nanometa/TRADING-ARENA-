import { NextResponse } from "next/server";

/// Proxy serveur pour l'historique BTC/USD (prix + volume).
/// Source primaire : Binance klines (quota très large, sans clé, renvoie volume).
/// Replis successifs : CoinGecko → dernière bonne réponse → série synthétique.
/// Sortie normalisée : { prices: [ms, price][], total_volumes: [ms, vol][] }.
export const dynamic = "force-dynamic";

const lastGood: Record<string, unknown> = {};

// Mapping période → (intervalle Binance, nombre de bougies).
function binanceParams(days: number): { interval: string; limit: number } {
  if (days <= 1) return { interval: "15m", limit: 96 }; // 24h
  if (days <= 7) return { interval: "1h", limit: 168 }; // 7j
  return { interval: "4h", limit: 180 }; // 30j
}

async function fromBinance(days: number) {
  const { interval, limit } = binanceParams(days);
  const res = await fetch(
    `https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=${interval}&limit=${limit}`,
    { cache: "no-store", signal: AbortSignal.timeout(5_000) },
  );
  if (!res.ok) throw new Error(`binance ${res.status}`);
  // Chaque kline : [openTime, open, high, low, close, volume, closeTime, ...].
  const klines = (await res.json()) as unknown[][];
  const prices: [number, number][] = [];
  const total_volumes: [number, number][] = [];
  for (const k of klines) {
    const openTime = Number(k[0]);
    const close = Number(k[4]);
    const volume = Number(k[5]);
    prices.push([openTime, close]);
    total_volumes.push([openTime, volume * close]); // volume en USD
  }
  return { prices, total_volumes };
}

async function fromCoingecko(days: number) {
  const res = await fetch(
    `https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=${days}`,
    { cache: "no-store", signal: AbortSignal.timeout(5_000) },
  );
  if (!res.ok) throw new Error(`coingecko ${res.status}`);
  return res.json();
}

function synthSeries(days: number) {
  const now = Date.now();
  const points = Math.min(300, Math.max(48, days * 24));
  const stepMs = (days * 24 * 60 * 60 * 1000) / points;
  let price = 60000;
  let seed = 987654321;
  const rand = () => {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };
  const prices: [number, number][] = [];
  const total_volumes: [number, number][] = [];
  for (let i = 0; i < points; i++) {
    const t = now - (points - i) * stepMs;
    price = Math.max(20000, price * (1 + (rand() - 0.5) * 0.02));
    prices.push([t, price]);
    total_volumes.push([t, 2e10 + rand() * 3e10]);
  }
  return { prices, total_volumes, _synthetic: true };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const days = searchParams.get("days") ?? "1";
  const d = Number(days);

  try {
    const data = await fromBinance(d);
    lastGood[days] = data;
    return NextResponse.json(data, {
      headers: { "Cache-Control": "public, s-maxage=60, stale-while-revalidate=120" },
    });
  } catch {
    try {
      const data = await fromCoingecko(d);
      lastGood[days] = data;
      return NextResponse.json(data, {
        headers: { "Cache-Control": "public, s-maxage=60, stale-while-revalidate=120" },
      });
    } catch {
      const fallback = lastGood[days] ?? synthSeries(d);
      return NextResponse.json(fallback, { headers: { "Cache-Control": "no-store" } });
    }
  }
}
