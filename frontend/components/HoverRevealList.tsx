"use client";

import { useState } from "react";
import { motion, useSpring, useMotionValue } from "framer-motion";
import { ArtImage } from "./ArtImage";

interface Item {
  label: string;
  sub?: string;
  art: number;
}

/// Liste brutaliste : au survol d'une ligne, une illustration SUIT le curseur
/// avec une physique de ressort (spring), au-dessus du texte (z-index haut).
/// Le texte passe d'outline à plein noir au hover.
export function HoverRevealList({ items }: { items: Item[] }) {
  const [active, setActive] = useState<number | null>(null);

  // Position brute de la souris.
  const mx = useMotionValue(0);
  const my = useMotionValue(0);
  // Position lissée par ressort (mouvement dynamique et fluide).
  const x = useSpring(mx, { stiffness: 250, damping: 28, mass: 0.6 });
  const y = useSpring(my, { stiffness: 250, damping: 28, mass: 0.6 });

  function onMove(e: React.MouseEvent) {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    mx.set(e.clientX - rect.left);
    my.set(e.clientY - rect.top);
  }

  return (
    <div className="relative" onMouseMove={onMove}>
      {/* Image flottante qui suit le curseur (spring), au-dessus du texte */}
      <motion.div
        className="pointer-events-none absolute z-30 hidden w-64 md:block"
        style={{ left: x, top: y, translateX: "-50%", translateY: "-50%" }}
        animate={{ opacity: active !== null ? 1 : 0, scale: active !== null ? 1 : 0.85 }}
        transition={{ duration: 0.35, ease: [0.32, 0.72, 0, 1] }}
      >
        {active !== null && (
          <ArtImage
            n={items[active].art}
            className="aspect-[4/5] w-full shadow-2xl"
            rounded="rounded-none"
          />
        )}
      </motion.div>

      <ul>
        {items.map((it, i) => (
          <li
            key={it.label}
            onMouseEnter={() => setActive(i)}
            onMouseLeave={() => setActive(null)}
            className="group flex items-center justify-between border-t border-hairline py-5 last:border-b md:py-7"
          >
            <span className="outline-text font-display text-6xl uppercase leading-[0.9] tracking-tightest md:text-8xl">
              {it.label}
            </span>
            {it.sub && (
              <span className="ml-4 hidden text-[10px] uppercase tracking-[0.25em] text-muted md:block">
                {it.sub}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}
