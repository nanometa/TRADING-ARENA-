import { createConfig, http } from "wagmi";
import { injected } from "@wagmi/core";
import { ritualTestnet } from "./ritual";

/// Configuration wagmi + RainbowKit ciblant le Ritual Chain Testnet (Req 8.1).
/// On évite WalletConnect côté dev/SSR, car son storage dépend de indexedDB.
/// Le bouton RainbowKit reste disponible avec les wallets injectés (MetaMask,
/// Rabby, Brave Wallet, etc.).
export const wagmiConfig = createConfig({
  chains: [ritualTestnet],
  connectors: [injected()],
  transports: {
    // Keep browser reads on the same origin. The backend proxy isolates the UI
    // from RPC CORS/transient browser failures while wallet writes still go
    // through the connected Ritual wallet provider.
    [ritualTestnet.id]: http("/api/rpc"),
  },
  ssr: false,
});
