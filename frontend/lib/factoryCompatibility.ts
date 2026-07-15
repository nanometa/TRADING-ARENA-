import { toFunctionSelector, type Hex } from "viem";

export const REQUIRED_FACTORY_FUNCTIONS = [
  "createAgent(uint8,uint256)",
  "listAgents()",
  "activeAgentCount()",
  "totalAgents()",
  "market()",
  "leaderboard()",
  "deployer()",
] as const;

// These selectors must be present in the AgentDeployer creation bytecode. They
// are the complete safe creation path used by the frontend before any fee is
// deposited into a newly-created agent.
export const REQUIRED_AGENT_FUNCTIONS = [
  "setExecutor(uint8,address)",
  "setEstimatedCallCost(uint256)",
  "fundFees(uint256)",
  "activate(uint32,uint32,uint32)",
  "setAutoReschedule(bool)",
] as const;

export function bytecodeSupports(
  code: Hex | undefined,
  signatures: readonly string[],
): boolean {
  if (!code || code === "0x") return false;
  const normalized = code.toLowerCase();
  return signatures.every((signature) =>
    normalized.includes(toFunctionSelector(signature).slice(2).toLowerCase()),
  );
}

export type FactoryGeneration = "v2" | "legacy-compatible" | "unsupported";

export function classifyFactoryGeneration(
  implementationVersion: bigint | null,
  factoryCode: Hex | undefined,
  deployerCode: Hex | undefined,
): FactoryGeneration {
  const factoryCompatible = bytecodeSupports(factoryCode, REQUIRED_FACTORY_FUNCTIONS);
  const agentsCompatible = bytecodeSupports(deployerCode, REQUIRED_AGENT_FUNCTIONS);

  if (!factoryCompatible || !agentsCompatible) return "unsupported";
  return implementationVersion !== null && implementationVersion >= 2n
    ? "v2"
    : "legacy-compatible";
}
