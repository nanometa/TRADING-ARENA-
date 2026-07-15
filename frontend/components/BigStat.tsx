"use client";

import { Reveal } from "./Reveal";

/// Chiffre géant éditorial (style detroit.paris) : un grand nombre + label discret.
export function BigStat({
  value,
  label,
  suffix,
}: {
  value: string;
  label: string;
  suffix?: string;
}) {
  return (
    <Reveal>
      <div className="border-t border-hairline pt-6">
        <div className="flex items-baseline gap-2">
          <span className="font-display text-7xl font-extrabold leading-none tracking-tighter text-cream md:text-8xl">
            {value}
          </span>
          {suffix && (
            <span className="font-display text-2xl font-bold text-accent">{suffix}</span>
          )}
        </div>
        <p className="mt-3 text-xs uppercase tracking-[0.25em] text-muted">{label}</p>
      </div>
    </Reveal>
  );
}
