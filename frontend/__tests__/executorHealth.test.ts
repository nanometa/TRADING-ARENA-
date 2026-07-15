import { describe, expect, it } from "vitest";
import {
  encodeAbiParameters,
  padHex,
  parseAbiParameters,
  type Address,
  type Hex,
} from "viem";
import {
  decodeLlmOutcome,
  executorFromLlmInput,
  summarizeExecutorHealth,
  type LlmObservation,
} from "../lib/executorHealth";

const EXECUTOR = "0xB42e435c4252A5a2E7440e37B609F00c61a0c91B" as Address;
const RESPONSE_ABI = parseAbiParameters(
  "bool, bytes, bytes, string, (string,string,string)",
);

function response(hasError: boolean, error = ""): Hex {
  return encodeAbiParameters(RESPONSE_ABI, [
    hasError,
    hasError ? "0x" : "0x1234",
    "0x",
    error,
    ["", "", ""],
  ]);
}

describe("Ritual LLM executor health", () => {
  it("extracts the executor from the first LLM input word", () => {
    const input = `${padHex(EXECUTOR, { size: 32 })}00` as Hex;
    expect(executorFromLlmInput(input)).toBe(EXECUTOR);
  });

  it("decodes direct successful and failed settlements", () => {
    expect(decodeLlmOutcome(response(false))).toEqual({ success: true, error: "" });
    expect(decodeLlmOutcome(response(true, "certificate unavailable"))).toEqual({
      success: false,
      error: "certificate unavailable",
    });
  });

  it("supports the legacy async envelope", () => {
    const wrapped = encodeAbiParameters(parseAbiParameters("bytes, bytes"), [
      "0x1234",
      response(false),
    ]);
    expect(decodeLlmOutcome(wrapped)).toEqual({ success: true, error: "" });
  });

  it("uses the latest settlement as the operational health signal", () => {
    const observations: LlmObservation[] = [
      {
        executor: EXECUTOR,
        success: true,
        error: "",
        blockNumber: 100n,
        txHash: `0x${"1".repeat(64)}`,
      },
      {
        executor: EXECUTOR,
        success: false,
        error: "certificate unavailable",
        blockNumber: 101n,
        txHash: `0x${"2".repeat(64)}`,
      },
    ];

    expect(summarizeExecutorHealth(EXECUTOR, observations)).toMatchObject({
      status: "unhealthy",
      recentCalls: 2,
      recentSuccesses: 1,
      recentFailures: 1,
      lastBlock: "101",
      lastError: "certificate unavailable",
    });
  });

  it("marks an unused registered executor as unknown, not healthy", () => {
    expect(summarizeExecutorHealth(EXECUTOR, [])).toMatchObject({
      status: "unknown",
      recentCalls: 0,
      lastTxHash: null,
    });
  });
});
