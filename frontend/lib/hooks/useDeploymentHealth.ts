"use client";

import { useCallback, useEffect, useState } from "react";
import {
  fetchDeploymentHealth,
  type DeploymentHealthResponse,
} from "@/lib/deploymentHealth";

export function useDeploymentHealth() {
  const [data, setData] = useState<DeploymentHealthResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setData(await fetchDeploymentHealth());
    } catch (cause) {
      setData(null);
      setError(
        cause instanceof Error
          ? cause.message
          : "Unable to verify the Ritual Arena deployment.",
      );
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
    isReady: Boolean(data?.ready),
    isCreationReady: Boolean(data?.creationReady),
    refresh,
  };
}
