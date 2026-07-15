import { describe, it, expect } from "vitest";
import fc from "fast-check";
import { sortTradesByBlockDesc } from "../../lib/validators";

// Feature: ritual-trading-arena, Property 25: Tri de l'historique des trades par bloc décroissant.
//
// Pour toute liste de trades, l'historique rendu est ordonné par numéro de bloc
// décroissant.
//
// Validates: Requirements 8.7
describe("Property 25 — tri de l'historique par bloc décroissant", () => {
  it("ordonne les trades par bloc décroissant", () => {
    fc.assert(
      fc.property(
        fc.array(fc.bigInt({ min: 0n, max: 10_000_000n }), { maxLength: 200 }),
        (blocks) => {
          const trades = blocks.map((b) => ({ block: b }));
          const sorted = sortTradesByBlockDesc(trades);

          // Même longueur (aucune perte).
          expect(sorted.length).toBe(trades.length);

          // Ordre décroissant pour chaque paire adjacente.
          for (let i = 1; i < sorted.length; i++) {
            expect(sorted[i - 1].block >= sorted[i].block).toBe(true);
          }
        },
      ),
      { numRuns: 200 },
    );
  });
});
