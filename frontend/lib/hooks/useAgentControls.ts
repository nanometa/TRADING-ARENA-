"use client";

import { useState } from "react";
import { useSendTransaction, useWriteContract } from "wagmi";
import { encodeFunctionData } from "viem";
import { tradingAgentAbi } from "@/lib/abis";

/// Hook pour les contrôles owner d'un agent (pause, reprise, arrêt/retrait d'urgence,
/// demande de prix). Réservés à l'owner côté contrat (Req 9.3–9.7).
export function useAgentControls(agentAddress: `0x${string}`) {
  const { writeContractAsync, isPending: isWriting } = useWriteContract();
  const { sendTransactionAsync, isPending: isSending } = useSendTransaction();
  const [error, setError] = useState<string | null>(null);

  async function call(
    fn:
      | "pause"
      | "resume"
      | "emergencyStop"
      | "emergencyWithdraw",
  ) {
    setError(null);
    try {
      return await writeContractAsync({
        address: agentAddress,
        abi: tradingAgentAbi,
        functionName: fn,
        args: [],
      });
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Transaction failed.");
      throw e;
    }
  }

  async function requestPrice() {
    setError(null);
    try {
      // requestPrice() calls Ritual's async HTTP precompile internally. Sending
      // encoded calldata avoids wagmi's eth_call simulation, which cannot model
      // Ritual's fulfilled replay and would reject a valid transaction.
      return await sendTransactionAsync({
        to: agentAddress,
        data: encodeFunctionData({
          abi: tradingAgentAbi,
          functionName: "requestPrice",
          args: [],
        }),
        gas: 3_000_000n,
      });
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : "Transaction failed.";
      setError(
        /user (rejected|denied)/i.test(message)
          ? "Transaction cancelled in the wallet."
          : "Price refresh could not be submitted. No additional action was taken.",
      );
      throw e;
    }
  }

  return {
    pause: () => call("pause"),
    resume: () => call("resume"),
    emergencyStop: () => call("emergencyStop"),
    emergencyWithdraw: () => call("emergencyWithdraw"),
    requestPrice,
    isPending: isWriting || isSending,
    error,
  };
}
