"use client";

/// Affiche un message d'erreur de transaction (Req 8.9). Les valeurs de formulaire
/// sont conservées par le composant parent (état non réinitialisé sur erreur).
export function TxErrorToast({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <div className="mt-3 rounded border border-danger/50 bg-danger/10 p-3 text-sm text-danger">
      <strong>Transaction failed:</strong>
      <p className="mt-1 break-words font-mono text-xs">{message}</p>
    </div>
  );
}
