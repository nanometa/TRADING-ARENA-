import { NextResponse } from "next/server";
import {
  createPublicClient,
  http,
  parseAbiItem,
  zeroAddress,
  type Address,
  type Hex,
} from "viem";
import { ritualTestnet, SYSTEM_ADDRESSES } from "@/lib/ritual";
import { teeServiceRegistryAbi } from "@/lib/abis";
import {
  LLM_PRECOMPILE,
  decodeLlmOutcome,
  executorFromLlmInput,
  summarizeExecutorHealth,
  type LlmObservation,
} from "@/lib/executorHealth";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const PRECOMPILE_CALLED = parseAbiItem(
  "event PrecompileCalled(address precompile, bytes input, bytes output)",
);
const DEFAULT_LOOKBACK_BLOCKS = 20_000;

function safeLookback() {
  const configured = Number(process.env.RITUAL_EXECUTOR_HEALTH_LOOKBACK ?? DEFAULT_LOOKBACK_BLOCKS);
  if (!Number.isFinite(configured) || configured < 1) return DEFAULT_LOOKBACK_BLOCKS;
  return Math.min(Math.trunc(configured), 100_000);
}

export async function GET() {
  try {
    const client = createPublicClient({
      chain: ritualTestnet,
      transport: http(process.env.RITUAL_RPC_URL ?? ritualTestnet.rpcUrls.default.http[0]),
    });
    const lookbackBlocks = safeLookback();
    const latestBlock = await client.getBlockNumber();
    const fromBlock = latestBlock > BigInt(lookbackBlocks) ? latestBlock - BigInt(lookbackBlocks) : 0n;

    const [services, logs] = await Promise.all([
      client.readContract({
        address: SYSTEM_ADDRESSES.teeRegistry,
        abi: teeServiceRegistryAbi,
        functionName: "getServicesByCapability",
        args: [1, true],
      }),
      client.getLogs({ event: PRECOMPILE_CALLED, fromBlock, toBlock: latestBlock }),
    ]);

    const observations: LlmObservation[] = [];
    for (const log of logs) {
      if (log.args.precompile?.toLowerCase() !== LLM_PRECOMPILE) continue;
      const executor = executorFromLlmInput(log.args.input as Hex);
      const outcome = decodeLlmOutcome(log.args.output as Hex);
      if (!executor || !outcome || log.blockNumber === null || !log.transactionHash) continue;
      observations.push({
        executor,
        success: outcome.success,
        error: outcome.error,
        blockNumber: log.blockNumber,
        txHash: log.transactionHash,
      });
    }

    const usableAddresses = services
      .filter(
        (service) =>
          service.isValid &&
          service.node.teeAddress !== zeroAddress &&
          service.node.publicKey !== "0x",
      )
      .map((service) => service.node.teeAddress as Address);
    const executors = usableAddresses.map((address) =>
      summarizeExecutorHealth(address, observations),
    );
    const recommendedExecutor =
      executors.find((executor) => executor.status === "healthy")?.address ?? null;

    return NextResponse.json(
      {
        checkedAtBlock: latestBlock.toString(),
        lookbackBlocks,
        recommendedExecutor,
        executors,
      },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown Ritual RPC error.";
    return NextResponse.json(
      { error: `Ritual executor health check failed: ${message}` },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
