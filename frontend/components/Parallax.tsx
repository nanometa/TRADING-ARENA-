"use client";

import { useRef, ReactNode } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

/// Effet parallaxe multi-couches : l'élément se déplace verticalement à une
/// vitesse différente du scroll (illusion de profondeur, style detroit.paris).
export function Parallax({
  children,
  speed = 0.3,
  className,
}: {
  children: ReactNode;
  speed?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "end start"],
  });
  // speed positif = monte plus vite ; négatif = traîne.
  const y = useTransform(scrollYProgress, [0, 1], [120 * speed, -120 * speed]);

  return (
    <div ref={ref} className={className}>
      <motion.div style={{ y }}>{children}</motion.div>
    </div>
  );
}
