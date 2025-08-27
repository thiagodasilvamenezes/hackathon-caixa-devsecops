#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?image ref}"
KEY="${2:-cosign.key}"

# Gera chaves se não existirem (usa COSIGN_PASSWORD se fornecida; senão, sem senha - demo)
if [ ! -f "${KEY}" ]; then
  echo "🔐 Gerando chave Cosign ..."
  COSIGN_PASSWORD="${COSIGN_PASSWORD:-}" cosign generate-key-pair
fi

COSIGN_YES=true COSIGN_PASSWORD="${COSIGN_PASSWORD:-}" cosign sign --key "${KEY}" "${IMAGE}"
echo "✅ Imagem assinada: ${IMAGE}"
