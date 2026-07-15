import {
  decodeAbiParameters,
  getAddress,
  parseAbiParameters,
  type Address,
  type Hex,
} from "viem";

export const LLM_PRECOMPILE = "0x0000000000000000000000000000000000000802" as const;

const LLM_RESPONSE_ABI = parseAbiParameters(
  "bool, bytes, bytes, string, (string,string,string)",
);
const ASYNC_ENVELOPE_ABI = parseAbiParameters("bytes, bytes");

export type ExecutorHealthStatus = "healthy" | "unhealthy" | "unknown";

export interface LlmObservation {
  executor: Address;
  success: boolean;
  error: string;
  blockNumber: bigint;
  txHash: Hex;
}

export interface ExecutorHealthItem {
  address: Address;
  status: ExecutorHealthStatus;
  recentCalls: number;
  recentSuccesses: number;
  recentFailures: number;
  lastBlock: string | null;
  lastTxHash: Hex | null;
  lastError: string | null;
}

export interface ExecutorHealthResponse {
  checkedAtBlock: string;
  lookbackBlocks: number;
  recommendedExecutor: Address | null;
  executors: ExecutorHealthItem[];
}

export function executorFromLlmInput(input: Hex): Address | null {
  if (!/^0x[0-9a-fA-F]{64,}$/.test(input)) return null;
  const firstWord = input.slice(2, 66);
  try {
    return getAddress(`0x${firstWord.slice(24)}`);
  } catch {
    return null;
  }
}

function decodeDirectLlmResponse(output: Hex) {
  const [hasError, , , errorMessage] = decodeAbiParameters(LLM_RESPONSE_ABI, output);
  return { success: !hasError, error: errorMessage };
}

/** Decode both the live direct response and the legacy `(simmedInput, actualOutput)` wrapper. */
export function decodeLlmOutcome(output: Hex): { success: boolean; error: string } | null {
  if (output === "0x") return null;
  try {
    return decodeDirectLlmResponse(output);
  } catch {
    try {
      const [, actualOutput] = decodeAbiParameters(ASYNC_ENVELOPE_ABI, output);
      if (actualOutput === "0x") return null;
      return decodeDirectLlmResponse(actualOutput);
    } catch {
      return null;
    }
  }
}

export function summarizeExecutorHealth(
  address: Address,
  observations: readonly LlmObservation[],
): ExecutorHealthItem {
  const matching = observations
    .filter((item) => item.executor.toLowerCase() === address.toLowerCase())
    .sort((a, b) => (a.blockNumber === b.blockNumber ? 0 : a.blockNumber > b.blockNumber ? -1 : 1));
  const latest = matching[0];
  const successes = matching.filter((item) => item.success).length;
  const failures = matching.length - successes;

  return {
    address,
    status: !latest ? "unknown" : latest.success ? "healthy" : "unhealthy",
    recentCalls: matching.length,
    recentSuccesses: successes,
    recentFailures: failures,
    lastBlock: latest?.blockNumber.toString() ?? null,
    lastTxHash: latest?.txHash ?? null,
    lastError: latest && !latest.success ? latest.error || "Unknown LLM executor error." : null,
  };
}

export async function fetchExecutorHealth(): Promise<ExecutorHealthResponse> {
  const response = await fetch("/api/ritual/executors", { cache: "no-store" });
  const body = (await response.json()) as ExecutorHealthResponse & { error?: string };
  if (!response.ok) {
    throw new Error(body.error ?? "Unable to verify Ritual LLM executor health.");
  }
  return body;
}
