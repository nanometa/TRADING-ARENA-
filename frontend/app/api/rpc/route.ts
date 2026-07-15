import { NextRequest, NextResponse } from "next/server";
import { ritualTestnet } from "@/lib/ritual";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const MAX_RPC_BODY_BYTES = 256_000;

export async function POST(request: NextRequest) {
  try {
    const rawBody = await request.text();
    if (!rawBody || rawBody.length > MAX_RPC_BODY_BYTES) {
      return NextResponse.json(
        { jsonrpc: "2.0", id: null, error: { code: -32600, message: "Invalid RPC request." } },
        { status: 400 },
      );
    }

    JSON.parse(rawBody);
    const upstream = await fetch(
      process.env.RITUAL_RPC_URL ?? ritualTestnet.rpcUrls.default.http[0],
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: rawBody,
        cache: "no-store",
      },
    );
    const body = await upstream.text();
    return new NextResponse(body, {
      status: upstream.status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return NextResponse.json(
      { jsonrpc: "2.0", id: null, error: { code: -32603, message: "Ritual RPC unavailable." } },
      { status: 502, headers: { "Cache-Control": "no-store" } },
    );
  }
}
