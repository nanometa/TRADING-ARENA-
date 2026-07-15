/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,

  // Allows production verification to use a dedicated output directory while
  // `next dev` is already running on localhost. Sharing `.next` between both
  // processes can leave missing vendor chunks on Windows.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",

  // Compression gzip des réponses.
  compress: true,

  // Retire l'en-tête "X-Powered-By: Next.js" (sécurité + octets en moins).
  poweredByHeader: false,

  // Supprime les console.* en production (sauf erreurs/avertissements).
  compiler: {
    removeConsole: { exclude: ["error", "warn"] },
  },

  // Imports optimisés : ne charge que ce qui est utilisé de ces gros paquets.
  experimental: {
    optimizePackageImports: [
      "lightweight-charts",
      "framer-motion",
      "wagmi",
      "viem",
    ],
  },
};

export default nextConfig;
