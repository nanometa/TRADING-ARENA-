import { defineChain } from "viem";

/// Définition du Ritual Chain Testnet (Chain ID 1979) pour viem/wagmi (Req 8.1).
export const ritualTestnet = defineChain({
  id: 1979,
  name: "Ritual Chain Testnet",
  nativeCurrency: { name: "Ritual", symbol: "RITUAL", decimals: 18 },
  rpcUrls: {
    default: {
      http: ["https://rpc.ritualfoundation.org"],
      webSocket: ["wss://rpc.ritualfoundation.org/ws"],
    },
  },
  blockExplorers: {
    default: {
      name: "Ritual Explorer",
      url: "https://explorer.ritualfoundation.org",
    },
  },
  contracts: {
    // Multicall3 (adresse vérifiée du skill ritual-dapp-deploy) — utilisé par
    // wagmi/viem pour batcher les lectures de contrats.
    multicall3: { address: "0x5577Ea679673Ec7508E9524100a188E7600202a3" },
  },
  testnet: true,
});

/// Adresses des contrats applicatifs déployés. Remplies après le déploiement
/// (script Deploy.s.sol) — voir README. NE PAS coder en dur d'adresses inventées.
export const ADDRESSES = {
  agentFactory: (process.env.NEXT_PUBLIC_AGENT_FACTORY ??
    "0x0000000000000000000000000000000000000000") as `0x${string}`,
  simpleMarket: (process.env.NEXT_PUBLIC_SIMPLE_MARKET ??
    "0x0000000000000000000000000000000000000000") as `0x${string}`,
  leaderboard: (process.env.NEXT_PUBLIC_LEADERBOARD ??
    "0x0000000000000000000000000000000000000000") as `0x${string}`,
} as const;

/// Config de l'arène pour rendre un agent créé IMMÉDIATEMENT opérationnel
/// (financement des frais + câblage exécuteur + activation de l'autopilote).
/// Les exécuteurs TEE sont redécouverts dans le registre officiel juste avant
/// chaque création ; aucune adresse d'exécuteur n'est conservée dans l'env.
export const ARENA = {
  // 0,35 couvre le pire cas LLM observé (~0,31) avec une petite marge.
  feeDeposit: process.env.NEXT_PUBLIC_FEE_DEPOSIT ?? "0.4",
  // Applied explicitly to agents created by the deployed legacy-compatible
  // Factory before any escrow funding. Factory v2 already uses this default.
  minimumCallReserve: "0.35",
  lockDuration: BigInt(process.env.NEXT_PUBLIC_LOCK_DURATION ?? "200000"),
  frequency: Number(process.env.NEXT_PUBLIC_FREQUENCY ?? "170"),
  // Série one-shot : le premier appel est directement LLM → décision → trade.
  // L'agent se replanifie seulement s'il reste sain et suffisamment financé.
  numCalls: Number(process.env.NEXT_PUBLIC_NUM_CALLS ?? "1"),
  // Fenêtre maximale Ritual : donne au keeper le plus de temps possible pour
  // prendre le slot, sans dépasser MAX_TTL=500.
  ttl: Number(process.env.NEXT_PUBLIC_TTL ?? "500"),
} as const;
export const SYSTEM_ADDRESSES = {
  ritualWallet: "0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948",
  scheduler: "0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B",
  teeRegistry: "0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F",
  asyncTracker: "0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5",
  asyncDelivery: "0x5A16214fF555848411544b005f7Ac063742f39F6",
} as const;
