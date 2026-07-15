/// Validateurs purs et helpers de calcul du frontend.
/// Ces fonctions sont testées par property-based testing (fast-check).

export const STRATEGIES = ["Trend Following", "Mean Reversion"] as const;
export type StrategyName = (typeof STRATEGIES)[number];

export const MIN_CAPITAL = 0.01;
export const MAX_CAPITAL = 999_999_999.99;
export const MAX_STRATEGY_LEN = 1000;

export interface FormValidationResult {
  valid: boolean;
  /** Champ fautif lorsque invalide ("strategy" | "capital"), sinon null. */
  field: "strategy" | "capital" | null;
  reason: string | null;
}

/// Valide le formulaire de création d'agent (Req 8.5, Property 23).
/// Accepte ssi la stratégie a 1..1000 caractères et le capital ∈ [0.01, 999 999 999.99].
export function validateCreateAgentForm(
  strategy: string,
  capital: number,
): FormValidationResult {
  if (strategy.length < 1 || strategy.length > MAX_STRATEGY_LEN) {
    return {
      valid: false,
      field: "strategy",
      reason: `Strategy must be between 1 and ${MAX_STRATEGY_LEN} characters.`,
    };
  }
  if (
    !Number.isFinite(capital) ||
    capital < MIN_CAPITAL ||
    capital > MAX_CAPITAL
  ) {
    return {
      valid: false,
      field: "capital",
      reason: `Initial capital must be between ${MIN_CAPITAL} and ${MAX_CAPITAL}.`,
    };
  }
  return { valid: true, field: null, reason: null };
}

/// Calcule la performance en pourcentage (Req 8.6, Property 24).
/// performance = (valeurPortefeuille − capitalInitial) / capitalInitial × 100.
export function performancePercent(
  portfolioValue: number,
  initialCapital: number,
): number {
  if (initialCapital <= 0) return 0;
  return ((portfolioValue - initialCapital) / initialCapital) * 100;
}

export interface TradeLike {
  block: bigint;
}

/// Trie une liste de trades par numéro de bloc décroissant (Req 8.7, Property 25).
/// Retourne une nouvelle liste (pure, n'altère pas l'entrée).
export function sortTradesByBlockDesc<T extends TradeLike>(trades: T[]): T[] {
  return [...trades].sort((a, b) => {
    if (a.block === b.block) return 0;
    return a.block > b.block ? -1 : 1;
  });
}
