import type { Config } from "tailwindcss";

/// Thème brutaliste minimal (detroit.paris) : blanc pur + noir profond + accent Ritual.
const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Palette officielle Ritual (ritual.net) — UNIQUEMENT ces couleurs.
        // paper = surface de fond (noir), ink = texte (blanc).
        paper: "#000000", // fond noir Ritual
        ink: "#ffffff", // texte blanc
        bg: "#000000",
        surface: "#0c0c0c", // surfaces légèrement relevées
        accent: "#1a6b4a", // vert officiel Ritual (ritual.net)
        ritualGreen: "#1a6b4a",
        muted: "#8a8a8a",
        hairline: "rgba(255,255,255,0.14)",
      },
      fontFamily: {
        display: ["Bebas Neue", "Anton", "Oswald", "ui-sans-serif", "sans-serif"],
        sans: ["Archivo", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
      letterSpacing: {
        tightest: "-0.05em",
        tighter2: "-0.02em",
      },
      transitionTimingFunction: {
        fluid: "cubic-bezier(0.32,0.72,0,1)",
      },
    },
  },
  plugins: [],
};

export default config;
