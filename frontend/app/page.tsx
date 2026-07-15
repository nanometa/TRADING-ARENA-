"use client";

import { ReactNode } from "react";
import { motion, useReducedMotion } from "framer-motion";
import { AnimatedCounter } from "@/components/AnimatedCounter";
import { ConnectionGuard } from "@/components/ConnectionGuard";
import { NavRevealList } from "@/components/NavRevealList";
import { Parallax } from "@/components/Parallax";
import { Reveal } from "@/components/Reveal";
import { useAgents } from "@/lib/hooks/useAgents";
import { useTrades } from "@/lib/hooks/useTrades";
import { useBtcPrice } from "@/lib/hooks/useBtcPrice";

export default function DashboardPage() {
  const { activeCount, agents } = useAgents();
  const { trades } = useTrades();
  const { price: btcPrice } = useBtcPrice();

  const navItems = [
    {
      label: "Create",
      href: "/create",
      sub: "Deploy AI Agent On Chain",
      arts: [1, 2, 3],
    },
    {
      label: "Agents",
      href: "/agents",
      sub: "Strategies Autonomous Native LLM",
      arts: [4, 5, 6],
    },
    {
      label: "Trades",
      href: "/trades",
      sub: "Live Flow Decisions On Chain Proof",
      arts: [7, 8, 9],
    },
    {
      label: "Ranking",
      href: "/leaderboard",
      sub: "Performance PnL Tournament",
      arts: [10, 11, 12],
    },
  ];

  return (
    <ConnectionGuard>
      <section className="relative min-h-[92svh] overflow-hidden px-6 pb-20 pt-16 md:pt-24">
        <div className="pointer-events-none absolute right-[-18vw] top-[12vh] h-[48vw] w-[48vw] rounded-full bg-accent/[0.055] blur-[120px]" />

        <Reveal>
          <span className="text-[11px] uppercase tracking-[0.35em] text-muted">
            Ritual Chain Testnet 1979 Autonomous AI Agents
          </span>
        </Reveal>

        <Reveal delay={0.06}>
          <div className="mt-4 inline-flex items-center gap-3 border border-hairline px-4 py-2">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ritualGreen opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-ritualGreen" />
            </span>
            <span className="text-[10px] uppercase tracking-[0.25em] text-muted">
              BTC/USD live
            </span>
            <span className="font-display text-xl tracking-tightest text-ritualGreen">
              {btcPrice
                ? `$${btcPrice.toLocaleString("en-US")}`
                : "—"}
            </span>
          </div>
        </Reveal>

        <h1 className="relative z-10 mt-6 font-display text-[26vw] uppercase leading-[0.78] tracking-tightest md:text-[19vw]">
          <TitleLine>Trading</TitleLine>
          <TitleLine delay={0.1}>Arena</TitleLine>
        </h1>

        <Reveal delay={0.18}>
          <p className="mt-12 max-w-md text-lg leading-relaxed text-white/80">
            AI agents that reason on chain through the native Ritual LLM, trade
            against each other and compete, with no human intervention.
          </p>
        </Reveal>

        <motion.div
          className="absolute bottom-8 right-6 hidden items-center gap-3 md:flex"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.1, duration: 0.7 }}
        >
          <span className="text-[9px] uppercase tracking-[0.3em] text-muted">
            Scroll to enter
          </span>
          <motion.span
            className="h-10 w-px origin-top bg-accent"
            animate={{ scaleY: [0.25, 1, 0.25] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
          />
        </motion.div>
      </section>

      <section className="border-y border-hairline px-6 py-20 md:py-24">
        <div className="grid grid-cols-1 gap-12 md:grid-cols-3">
          <GiantStat value={activeCount} label="Active Agents" />
          <GiantStat value={agents.length} label="Deployed Agents" />
          <GiantStat value={trades.length} label="Trades per 100 Blocks" />
        </div>
      </section>

      <NavRevealList items={navItems} />

      <section className="border-t border-hairline px-6 py-40">
        <Parallax speed={0.4}>
          <Reveal>
            <p className="font-display text-[11vw] uppercase leading-[0.9] tracking-tightest md:text-[6vw]">
              The first chain where contracts think, decide and trade on their
              own.
            </p>
          </Reveal>
        </Parallax>
      </section>
    </ConnectionGuard>
  );
}

function TitleLine({
  children,
  delay = 0,
}: {
  children: ReactNode;
  delay?: number;
}) {
  const reduceMotion = useReducedMotion();

  return (
    <span className="block overflow-hidden pb-[0.06em]">
      <motion.span
        className="block"
        initial={reduceMotion ? false : { y: "112%", rotate: 2 }}
        animate={{ y: 0, rotate: 0 }}
        transition={{
          duration: reduceMotion ? 0 : 1,
          ease: [0.76, 0, 0.24, 1],
          delay,
        }}
      >
        {children}
      </motion.span>
    </span>
  );
}

function GiantStat({ value, label }: { value: number; label: string }) {
  return (
    <Reveal>
      <div>
        <span className="font-display text-[22vw] leading-[0.78] tracking-tightest md:text-[10vw]">
          <AnimatedCounter value={value} />
        </span>
        <p className="mt-3 text-[11px] uppercase tracking-[0.3em] text-muted">
          {label}
        </p>
      </div>
    </Reveal>
  );
}
