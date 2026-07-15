"use client";

import { useEffect, useRef, useState } from "react";

/// Affiche une illustration depuis /public/art/{n}.png (ou .jpg via prop `ext`).
/// Tant que l'image n'existe pas, un placeholder numéroté élégant s'affiche —
/// l'utilisateur dépose ses ~40 visuels plus tard sans toucher au code.
export function ArtImage({
  n,
  ext = "png",
  alt = "",
  className = "",
  rounded = "rounded-[1.5rem]",
}: {
  n: number;
  ext?: string;
  alt?: string;
  className?: string;
  rounded?: string;
}) {
  // Essaie d'abord le PNG (tes vraies images), puis le SVG (images de test),
  // puis le placeholder numéroté.
  const candidates = [`/art/${n}.${ext}`, `/art/${n}.svg`, `/art/${n}.jpg`];
  const [idx, setIdx] = useState(0);
  const imageRef = useRef<HTMLImageElement>(null);
  const failed = idx >= candidates.length;
  const src = failed ? "" : candidates[idx];

  // Une image manquante peut échouer avant que React n'ait hydraté la page.
  // Dans ce cas l'événement onError est perdu : on contrôle aussi l'état réel
  // de l'image après montage afin de passer proprement au fallback suivant.
  useEffect(() => {
    const image = imageRef.current;
    if (!image) return;

    const useNextCandidate = () => {
      setIdx((current) => current + 1);
    };

    image.addEventListener("error", useNextCandidate);
    const missedErrorCheck = window.setTimeout(() => {
      if (image.complete && image.naturalWidth === 0) {
        useNextCandidate();
      }
    }, 0);

    return () => {
      window.clearTimeout(missedErrorCheck);
      image.removeEventListener("error", useNextCandidate);
    };
  }, [src]);

  if (failed) {
    return (
      <div
        className={`relative flex items-center justify-center overflow-hidden bg-ink/[0.04] ${rounded} ${className}`}
        aria-label={alt || `Illustration ${n}`}
      >
        <div className="absolute inset-0 bg-gradient-to-br from-accent/10 via-transparent to-ritualGreen/10" />
        <span className="font-display text-7xl text-ink/10">
          {String(n).padStart(2, "0")}
        </span>
        <span className="absolute bottom-3 left-3 text-[10px] uppercase tracking-[0.2em] text-muted">
          art/{n}.{ext}
        </span>
      </div>
    );
  }

  // eslint-disable-next-line @next/next/no-img-element
  return (
    <img
      key={src}
      ref={imageRef}
      src={src}
      alt={alt || `Illustration ${n}`}
      className={`object-cover ${rounded} ${className}`}
      loading="lazy"
    />
  );
}
