import { describe, it, expect } from "vitest";
import fc from "fast-check";
import { performancePercent } from "../../lib/validators";

// Feature: ritual-trading-arena, Property 24: Calcul de la performance en pourcentage.
//
// Pour toute valeur de portefeuille et capital initial strictement positif, la
// performance affichée est exactement (valeurPortefeuille − capitalInitial) /
// capitalInitial × 100.
//
// Validates: Requirements 8.6
describe("Property 24 — performance en pourcentage", () => {
  it("performance = (valeur - initial) / initial * 100", () => {
    fc.assert(
      fc.property(
        fc.double({ min: 0, max: 1e12, noNaN: true }),
        fc.double({ min: 0.01, max: 1e12, noNaN: true }),
        (portfolioValue, initialCapital) => {
          const got = performancePercent(portfolioValue, initialCapital);
          const expected =
            ((portfolioValue - initialCapital) / initialCapital) * 100;
          // Égalité flottante exacte (même expression arithmétique).
          expect(got).toBeCloseTo(expected, 9);
        },
      ),
      { numRuns: 200 },
    );
  });

  it("retourne 0 si capital initial <= 0 (garde-fou)", () => {
    expect(performancePercent(100, 0)).toBe(0);
    expect(performancePercent(100, -5)).toBe(0);
  });
});
