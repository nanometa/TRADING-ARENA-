import { describe, it, expect } from "vitest";
import fc from "fast-check";
import {
  validateCreateAgentForm,
  MIN_CAPITAL,
  MAX_CAPITAL,
  MAX_STRATEGY_LEN,
} from "../../lib/validators";

// Feature: ritual-trading-arena, Property 23: Validation du formulaire de création.
//
// Pour tout couple (stratégie, capital initial) saisi, le validateur accepte la
// soumission si et seulement si la stratégie a une longueur de 1 à 1000 caractères
// et le capital est dans [0.01, 999 999 999.99] ; sinon il rejette en indiquant le
// champ fautif.
//
// Validates: Requirements 8.5
describe("Property 23 — validation du formulaire", () => {
  it("accepte ssi stratégie 1..1000 et capital dans [0.01, 999 999 999.99]", () => {
    fc.assert(
      fc.property(
        fc.string({ maxLength: 1200 }),
        fc.double({ min: -1e12, max: 1e12, noNaN: true }),
        (strategy, capital) => {
          const res = validateCreateAgentForm(strategy, capital);

          const strategyOk =
            strategy.length >= 1 && strategy.length <= MAX_STRATEGY_LEN;
          const capitalOk =
            Number.isFinite(capital) &&
            capital >= MIN_CAPITAL &&
            capital <= MAX_CAPITAL;
          const expectedValid = strategyOk && capitalOk;

          expect(res.valid).toBe(expectedValid);

          if (!res.valid) {
            // Le champ fautif est correctement identifié (priorité stratégie).
            if (!strategyOk) {
              expect(res.field).toBe("strategy");
            } else {
              expect(res.field).toBe("capital");
            }
          } else {
            expect(res.field).toBeNull();
          }
        },
      ),
      { numRuns: 200 },
    );
  });

  it("accepte les bornes exactes", () => {
    expect(validateCreateAgentForm("Trend Following", MIN_CAPITAL).valid).toBe(
      true,
    );
    expect(validateCreateAgentForm("Mean Reversion", MAX_CAPITAL).valid).toBe(
      true,
    );
  });
});
