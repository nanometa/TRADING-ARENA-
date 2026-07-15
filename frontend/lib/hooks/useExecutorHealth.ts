"use client";

import { useCallback, useEffect, useState } from "react";
import {
  fetchExecutorHealth,
  type ExecutorHealthResponse,
} from "@/lib/executorHealth";

export function useExecutorHealth() {
  const [data, setData] = useState<ExecutorHealthResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setData(await fetchExecutorHealth());
    } catch (cause) {
      setData(null);
      setError(cause instanceof Error ? cause.message : "Unable to verify Ritual LLM executor health.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
    const timer = window.setInterval(() => void refresh(), 30_000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  return {
    data,
    error,
    isLoading,
    isHealthy: Boolean(data?.recommendedExecutor),
    refresh,
  };
}
