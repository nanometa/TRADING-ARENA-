"use client";

import { useState } from "react";
import { useWriteContract, usePublicClient } from "wagmi";
import { parseEther, decodeEventLog } from "viem";
import { ADDRESSES, ARENA } from "@/lib/ritual";
import { agentFactoryAbi, tradingAgentAbi } from "@/lib/abis";
import { fetchExecutorHealth } from "@/lib/executorHealth";
import { fetchDeploymentHealth } from "@/lib/deploymentHealth";

function friendlyCreationError(error: unknown) {
  const message = error instanceof Error ? error.message : "Agent creation failed.";
  const lower = message.toLowerCase();

  if (lower.includes("user rejected") || lower.includes("user denied")) {
    return "Transaction cancelled in the wallet.";
  }
  if (lower.includes("insufficient funds")) {
    return "Insufficient RITUAL balance for this operation.";
  }
  if (lower.includes("no registered ritual llm executor")) {
    return "Ritual services are preparing the request. Please try again shortly.";
  }
  if (lower.includes("deployment") || lower.includes("factory")) {
    return "Ritual Arena is preparing the request. Please try again shortly.";
  }
  return "The request could not be completed. Please try again.";
}

/// Hook d'écriture : crée un agent PUIS le rend opérationnel — câblage des
/// exécuteurs TEE + financement des frais + activation de l'autopilote — en
/// séquence, pour qu'un agent créé par un utilisateur trade réellement (Req 8.9).
export function useCreateAgent() {
  const { writeContractAsync, isPending: isWalletPending } = useWriteContract();
  const publicClient = usePublicClient();
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState<string>("");
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);
  const [isCreating, setIsCreating] = useState(false);

  /// @param strategyIndex 0 = trend-following, 1 = mean-reversion
  /// @param capital capital initial en RITUAL (string décimal)
  async function createAgent(strategyIndex: number, capital: string) {
    setError(null);
    setTxHash(null);
    setIsCreating(true);
    try {
      if (!publicClient) throw new Error("Ritual RPC client unavailable.");

      const confirm = async (hash: `0x${string}`, label: string) => {
        setTxHash(hash);
        const receipt = await publicClient.waitForTransactionReceipt({ hash });
        if (receipt.status !== "success") throw new Error(`${label} reverted.`);
        return receipt;
      };

      const feeDeposit = parseEther(ARENA.feeDeposit);
      if (feeDeposit < parseEther("0.35")) {
        throw new Error("LLM fee deposit must be at least 0.35 RITUAL.");
      }

      // Both checks happen before the first wallet request: the backend verifies
      // the deployed Factory wiring/bytecode and discovers registered executors.
      setStep("Verifying Ritual services…");
      const [deployment, executorHealth] = await Promise.all([
        fetchDeploymentHealth(),
        fetchExecutorHealth(),
      ]);
      if (!deployment.creationReady) {
        throw new Error("Ritual Arena deployment is not ready for safe creation.");
      }
      // Prefer a recently healthy executor. If Ritual currently reports none as
      // healthy, still allow the user-requested transaction with the first valid
      // executor registered for the LLM capability.
      const llmExecutor =
        executorHealth.recommendedExecutor ?? executorHealth.executors[0]?.address;
      if (!llmExecutor) {
        throw new Error("No registered Ritual LLM executor is available.");
      }

      // 1) Créer l'agent via la Factory.
      setStep("Creating agent…");
      const hash = await writeContractAsync({
        address: ADDRESSES.agentFactory,
        abi: agentFactoryAbi,
        functionName: "createAgent",
        args: [strategyIndex, parseEther(capital)],
        gas: 7_000_000n,
      });

      // 2) Récupérer l'adresse de l'agent depuis l'event AgentCreated.
      const receipt = await confirm(hash, "Agent creation");
      let agent: `0x${string}` | undefined;
      for (const log of receipt.logs) {
        if (log.address.toLowerCase() !== ADDRESSES.agentFactory.toLowerCase()) continue;
        try {
          const parsed = decodeEventLog({
            abi: agentFactoryAbi,
            data: log.data,
            topics: log.topics,
          });
          if (parsed.eventName === "AgentCreated") {
            agent = (parsed.args as { agent: `0x${string}` }).agent;
            break;
          }
        } catch {
          // log d'un autre contrat / autre évènement — ignorer.
        }
      }
      if (!agent) throw new Error("Adresse de l'agent introuvable dans le reçu.");

      // 3) Câbler uniquement l'exécuteur LLM requis par l'autopilote. Le prix HTTP
      //    est optionnel et ne doit pas ajouter une transaction au chemin critique.
      setStep("Configuring autonomous engine…");
      const llmHash = await writeContractAsync({
        address: agent,
        abi: tradingAgentAbi,
        functionName: "setExecutor",
        args: [1, llmExecutor],
        gas: 150_000n,
      });
      await confirm(llmHash, "LLM executor setup");

      // The latest deployed Kiro Factory predates the explicit v2 getter. Its
      // agents expose the safety setter, so raise their old 0.005 reserve to the
      // current 0.35 RIT minimum before depositing any fee escrow.
      if (deployment.generation === "legacy-compatible") {
        setStep("Applying fee protection…");
        const reserveHash = await writeContractAsync({
          address: agent,
          abi: tradingAgentAbi,
          functionName: "setEstimatedCallCost",
          args: [parseEther(ARENA.minimumCallReserve)],
          gas: 120_000n,
        });
        await confirm(reserveHash, "Fee protection setup");
      }

      // 4) Financer les frais (RitualWallet de l'agent). Le minimum de sécurité
      //    est 0,35 RITUAL ; la valeur par défaut du frontend est 0,4.
      setStep("Funding agent fees…");
      const fundingHash = await writeContractAsync({
        address: agent,
        abi: tradingAgentAbi,
        functionName: "fundFees",
        args: [ARENA.lockDuration],
        value: feeDeposit,
        gas: 350_000n,
      });
      await confirm(fundingHash, "Fee funding");

      // 5) Activer l'autopilote (planification autonome).
      setStep("Activating autopilot…");
      const activationHash = await writeContractAsync({
        address: agent,
        abi: tradingAgentAbi,
        functionName: "activate",
        args: [ARENA.frequency, ARENA.numCalls, ARENA.ttl],
        gas: 3_000_000n,
      });
      await confirm(activationHash, "Autopilot activation");

      setStep("Done");
      return hash;
    } catch (e: unknown) {
      const msg = friendlyCreationError(e);
      setError(msg);
      throw new Error(msg);
    } finally {
      setIsCreating(false);
    }
  }

  return {
    createAgent,
    isPending: isWalletPending || isCreating,
    error,
    txHash,
    step,
  };
}
