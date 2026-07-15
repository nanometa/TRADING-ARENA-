"use client";

import Link from "next/link";
import Image from "next/image";
import { useChainId } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { ritualTestnet } from "@/lib/ritual";

/// Minimal brutalist navbar: logo + RainbowKit connect button. Main navigation
/// is the large list on the home page (detroit.paris style).
export function NavBar() {
  const chainId = useChainId();
  const onRitual = chainId === ritualTestnet.id;

  return (
    <header className="sticky top-0 z-40 border-b border-hairline bg-paper/80 backdrop-blur-xl">
      <nav className="mx-auto flex max-w-[1600px] items-center justify-between px-10 py-4">
        <Link
          href="/"
          className="group flex items-center gap-3 font-display text-2xl uppercase tracking-tightest md:text-[32px]"
        >
          <span>
            Ritual<span className="text-ritualGreen">/</span>Arena
          </span>
          <Image
            src="/brand/ritual-arena-logo.png"
            alt="Ritual Arena logo"
            width={46}
            height={46}
            priority
            className="h-10 w-10 border border-ritualGreen/50 object-cover shadow-[0_0_22px_rgba(26,107,74,0.35)] md:h-[46px] md:w-[46px]"
          />
        </Link>

        <div className="ml-auto flex items-center gap-5 pr-8">
          <span
            className={`hidden text-[10px] font-bold uppercase tracking-[0.2em] sm:inline ${
              onRitual ? "text-ritualGreen" : "text-accent"
            }`}
          >
            {onRitual ? "● 1979" : "⚠ network"}
          </span>
          <ConnectButton
            showBalance={false}
            accountStatus="address"
            chainStatus="none"
          />
        </div>
      </nav>
    </header>
  );
}
