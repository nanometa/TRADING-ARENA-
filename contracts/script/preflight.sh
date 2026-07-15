#!/usr/bin/env bash
# Préflight testnet (lecture seule, aucun RITUAL requis).
# Vérifie : code des contrats système + présence d'un exécuteur TEE LLM.
export PATH="$PATH:$HOME/.foundry/bin"
RPC="https://rpc.ritualfoundation.org"

echo "=== Chain ID ==="
cast chain-id --rpc-url "$RPC"

echo ""
echo "=== Code des contrats systeme (doit etre != 0x) ==="
for pair in \
  "RitualWallet:0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948" \
  "Scheduler:0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B" \
  "TEEServiceRegistry:0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F" \
  "AsyncJobTracker:0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5" \
  "AsyncDelivery:0x5A16214fF555848411544b005f7Ac063742f39F6" \
  "SovereignFactory:0x9dC4C054e53bCc4Ce0A0Ff09E890A7a8e817f304" \
  "PersistentFactory:0xD4AA9D55215dc8149Af57605e70921Ea16b73591" ; do
  name="${pair%%:*}"
  addr="${pair##*:}"
  code=$(cast code "$addr" --rpc-url "$RPC" 2>/dev/null)
  if [ -z "$code" ] || [ "$code" = "0x" ]; then
    echo "  [VIDE] $name ($addr) -> PAS DE CODE"
  else
    len=${#code}
    echo "  [OK]   $name ($addr) -> $((len/2)) octets"
  fi
done

echo ""
echo "=== Executeurs TEE pour HTTP_CALL (capacite 0) ==="
cast call 0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F \
  "getServicesByCapability(uint8,bool)(((address,address,uint8,bytes,string,bytes32,uint8),bool,bytes32)[])" \
  0 true --rpc-url "$RPC" 2>&1 | cut -c1-600
echo ""
echo "(Si la liste est vide '[]', aucun executeur n'est en ligne actuellement.)"

echo ""
echo "=== Executeurs TEE pour LLM (capacite 1, requis) ==="
cast call 0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F \
  "getServicesByCapability(uint8,bool)(((address,address,uint8,bytes,string,bytes32,uint8),bool,bytes32)[])" \
  1 true --rpc-url "$RPC" 2>&1 | cut -c1-600
