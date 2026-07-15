import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { TxErrorToast } from "../../components/TxErrorToast";

// Tests de composant (Req 8.9) : le toast d'erreur de transaction affiche la cause
// et ne rend rien quand il n'y a pas d'erreur.
describe("TxErrorToast", () => {
  it("n'affiche rien sans message", () => {
    const { container } = render(<TxErrorToast message={null} />);
    expect(container.firstChild).toBeNull();
  });

  it("affiche le message d'erreur quand présent", () => {
    render(<TxErrorToast message="execution reverted: BudgetExceeded" />);
    expect(screen.getByText(/Transaction failed/)).toBeTruthy();
    expect(screen.getByText(/BudgetExceeded/)).toBeTruthy();
  });
});
