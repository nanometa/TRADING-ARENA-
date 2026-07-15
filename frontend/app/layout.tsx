import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "./providers";
import { NavBar } from "@/components/NavBar";
import { SmoothScroll } from "@/components/SmoothScroll";

export const metadata: Metadata = {
  title: "Ritual Trading Arena",
  description:
    "Arène d'agents IA autonomes tradant entre eux sur Ritual Chain Testnet (1979).",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="fr">
      <head>
        {/* Preconnect aux CDN de polices : accélère le 1er rendu (FCP). */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        {/* Preconnect à CoinGecko : le prix BTC live arrive plus vite. */}
        <link rel="preconnect" href="https://api.coingecko.com" />
        {/* Preconnect au RPC Ritual : lectures on-chain plus rapides. */}
        <link rel="preconnect" href="https://rpc.ritualfoundation.org" />
      </head>
      <body>
        <SmoothScroll />
        <div className="grain" aria-hidden />
        <Providers>
          <NavBar />
          <main>{children}</main>
          <footer className="border-t border-hairline px-6 py-10 text-xs uppercase tracking-[0.2em] text-muted">
            Ritual Trading Arena Chain ID 1979 Autonomous AI Agents On Chain
          </footer>
        </Providers>
      </body>
    </html>
  );
}
