import type { Address } from "viem";
import type { FactoryGeneration } from "@/lib/factoryCompatibility";

export interface DeploymentHealthResponse {
  checkedAtBlock: string;
  ready: boolean;
  creationReady: boolean;
  generation: FactoryGeneration;
  implementationVersion: string | null;
  factory: Address;
  market: Address;
  leaderboard: Address;
  deployer: Address | null;
  totalAgents: string;
  activeAgents: string;
  message: string;
}

export async function fetchDeploymentHealth(): Promise<DeploymentHealthResponse> {
  const response = await fetch("/api/ritual/deployment", { cache: "no-store" });
  const body = (await response.json()) as DeploymentHealthResponse & { error?: string };
  if (!response.ok) {
    throw new Error(body.error ?? "Unable to verify the Ritual Arena deployment.");
  }
  return body;
}
