"use client";

import { useState } from "react";
import {
  MAX_CAPITAL,
  MIN_CAPITAL,
  STRATEGIES,
  validateCreateAgentForm,
} from "@/lib/validators";
import { useCreateAgent } from "@/lib/hooks/useCreateAgent";
import { useExecutorHealth } from "@/lib/hooks/useExecutorHealth";
import { useDeploymentHealth } from "@/lib/hooks/useDeploymentHealth";
import { TxErrorToast } from "./TxErrorToast";

/// Formulaire de création d'agent avec validation avant soumission (Req 8.4, 8.5).
/// Les valeurs saisies sont conservées en cas d'erreur (Req 8.5, 8.9).
export function CreateAgentForm() {
  const [strategy, setStrategy] = useState<string>(STRATEGIES[0]);
  const [capital, setCapital] = useState<string>("10");
  const [fieldError, setFieldError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const { createAgent, isPending, error, step } = useCreateAgent();
  const executorHealth = useExecutorHealth();
  const deploymentHealth = useDeploymentHealth();
  const servicesLoading = executorHealth.isLoading || deploymentHealth.isLoading;
  const creationReady = executorHealth.isHealthy && deploymentHealth.isCreationReady;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSuccess(null);
    setFieldError(null);

    const capitalNum = Number(capital);
    const res = validateCreateAgentForm(strategy, capitalNum);
    if (!res.valid) {
      setFieldError(res.reason);
      return; // les valeurs saisies sont conservées
    }

    const strategyIndex = STRATEGIES.indexOf(strategy as (typeof STRATEGIES)[number]);
    try {
      const hash = await createAgent(strategyIndex >= 0 ? strategyIndex : 0, capital);
      setSuccess(`Agent created, funded & activated. Tx ${hash}`);
    } catch {
      // erreur affichée via TxErrorToast (valeurs conservées)
    }
  }

  return (
    <form onSubmit={onSubmit} className="max-w-md space-y-6">
      <div>
        <label className="mb-2 block text-xs uppercase tracking-[0.2em] text-muted">Strategy</label>
        <select
          value={strategy}
          onChange={(e) => setStrategy(e.target.value)}
          className="w-full border border-ink bg-transparent px-4 py-3 text-sm uppercase tracking-wide focus:border-accent focus:outline-none"
        >
          {STRATEGIES.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label className="mb-2 block text-xs uppercase tracking-[0.2em] text-muted">
          Simulated Initial Capital (RITUAL) from 0.01 to 999999999.99
        </label>
        <input
          type="number"
          step="0.01"
          min={MIN_CAPITAL}
          max={MAX_CAPITAL}
          inputMode="decimal"
          value={capital}
          onChange={(e) => setCapital(e.target.value)}
          className="w-full border border-ink bg-transparent px-4 py-3 text-sm tabular-nums focus:border-accent focus:outline-none"
        />
      </div>

      <p className="text-xs text-muted">
        The simulated capital is not charged to your wallet. Creating the agent funds 0.4 RITUAL of LLM
        fees and starts one protected autopilot cycle. Continuous rescheduling stays disabled until it is
        explicitly enabled.
      </p>

      <div className="space-y-2 border border-border bg-panel p-3 text-xs">
        <ServiceState
          loading={deploymentHealth.isLoading}
          ready={deploymentHealth.isCreationReady}
          readyLabel={`Latest Factory connected · ${deploymentHealth.data?.activeAgents ?? "0"} active agents`}
          waitingLabel="Arena contracts are syncing. Creation remains protected."
        />
        <ServiceState
          loading={executorHealth.isLoading}
          ready={executorHealth.isHealthy}
          readyLabel="Ritual autonomous execution services are ready."
          waitingLabel="Agent creation will open automatically when all Ritual services are ready."
        />
      </div>

      {fieldError && <p className="text-sm text-accent">{fieldError}</p>}

      <button
        type="submit"
        disabled={isPending || servicesLoading || !creationReady}
        className="bg-ink px-7 py-4 text-xs uppercase tracking-[0.2em] text-paper transition-colors duration-500 hover:bg-accent disabled:opacity-50"
      >
        {isPending ? (step ? step : "Creating…") : "Create Agent"}
      </button>

      {success && <p className="text-sm text-ritualGreen">{success}</p>}
      <TxErrorToast message={error} />
    </form>
  );
}

function ServiceState({
  loading,
  ready,
  readyLabel,
  waitingLabel,
}: {
  loading: boolean;
  ready: boolean;
  readyLabel: string;
  waitingLabel: string;
}) {
  return (
    <div className="flex items-start gap-2">
      <span
        className={`mt-1 h-1.5 w-1.5 shrink-0 rounded-full ${
          loading ? "animate-pulse bg-muted" : ready ? "bg-ritualGreen" : "bg-accent"
        }`}
      />
      <p className={ready ? "text-ritualGreen" : "text-muted"}>
        {loading ? "Checking Ritual services…" : ready ? readyLabel : waitingLabel}
      </p>
    </div>
  );
}
