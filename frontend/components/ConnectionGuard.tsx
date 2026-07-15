"use client";

import { ReactNode, useEffect, useState } from "react";
import { usePublicClient } from "wagmi";

/// ConnectionGuard — vérifie la connexion au Ritual Chain Testnet avec un timeout
/// de 10 s (Req 8.1). En cas d'échec/timeout, affiche un message + bouton
/// « Réessayer » SANS bloquer le rendu des sections statiques (Req 8.2).
export function ConnectionGuard({ children }: { children: ReactNode }) {
  const publicClient = usePublicClient();
  const [state, setState] = useState<"checking" | "ok" | "error">("checking");
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setState("checking");

    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), 10_000),
    );

    const probe = (async () => {
      if (!publicClient) throw new Error("no client");
      await publicClient.getBlockNumber();
    })();

    Promise.race([probe, timeout])
      .then(() => {
        if (!cancelled) setState("ok");
      })
      .catch(() => {
        if (!cancelled) setState("error");
      });

    return () => {
      cancelled = true;
    };
  }, [publicClient, attempt]);

  return (
    <div>
      {state === "error" && (
        <div className="border-b border-accent/40 bg-accent/10 px-6 py-3 text-sm">
          <p className="text-accent">
            Cannot connect to Ritual Chain Testnet 1979 or connection timed out
            after 10 seconds.
          </p>
          <button
            onClick={() => setAttempt((a) => a + 1)}
            className="mt-2 border border-accent px-3 py-1 text-xs uppercase tracking-[0.15em] hover:bg-accent hover:text-paper"
          >
            Retry
          </button>
        </div>
      )}
      {/* Les sections statiques restent rendues quel que soit l'état (Req 8.2). */}
      {children}
    </div>
  );
}
