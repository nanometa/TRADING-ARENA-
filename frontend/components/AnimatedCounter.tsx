"use client";

import { useEffect, useRef } from "react";
import {
  animate,
  motion,
  useInView,
  useMotionValue,
  useReducedMotion,
  useTransform,
} from "framer-motion";

export function AnimatedCounter({ value }: { value: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true, margin: "-10%" });
  const reduceMotion = useReducedMotion();
  const progress = useMotionValue(0);
  const displayed = useTransform(progress, (latest) =>
    Math.round(latest).toString(),
  );

  useEffect(() => {
    if (!inView) return;

    if (reduceMotion) {
      progress.set(value);
      return;
    }

    const controls = animate(progress, value, {
      duration: 1.25,
      ease: [0.32, 0.72, 0, 1],
    });

    return controls.stop;
  }, [inView, progress, reduceMotion, value]);

  return <motion.span ref={ref}>{displayed}</motion.span>;
}
