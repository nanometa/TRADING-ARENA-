"use client";

import { motion } from "framer-motion";
import { ReactNode } from "react";

/// Animation d'entrée fluide (fade-up + blur) déclenchée à l'entrée dans le viewport.
/// Utilise transform/opacity uniquement (GPU-safe).
export function Reveal({
  children,
  delay = 0,
  className,
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
}) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: 28, filter: "blur(8px)" }}
      whileInView={{ opacity: 1, y: 0, filter: "blur(0px)" }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{ duration: 0.8, ease: [0.32, 0.72, 0, 1], delay }}
    >
      {children}
    </motion.div>
  );
}
