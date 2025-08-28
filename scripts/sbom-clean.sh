#!/usr/bin/env bash
set -euo pipefail

# Move SBOM files larger than threshold to sbom/archive and compress them.
# Usage: scripts/sbom-clean.sh [--threshold-bytes N]

THRESHOLD=${1:-0}
SCRIPT_DIR="$(dirname "$0")"
ARCHIVE_DIR="$SCRIPT_DIR/../sbom/archive"
SBOM_DIR="$SCRIPT_DIR/../sbom"

# Ensure directories exist
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$SBOM_DIR"

# Get absolute paths to avoid issues
ARCHIVE_DIR_ABS="$(realpath "$ARCHIVE_DIR")"
SBOM_DIR_ABS="$(realpath "$SBOM_DIR")"

cd "$SBOM_DIR_ABS"

# Find files larger than threshold (or all if threshold=0)
if [ "$THRESHOLD" -eq 0 ]; then
  FILES=( $(ls -1t *.json *.spdx 2>/dev/null || true) )
else
  # Using find to match files larger than threshold
  mapfile -t FILES < <(find . -maxdepth 1 -type f -size +${THRESHOLD}c -printf "%f\n" 2>/dev/null)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Nenhum SBOM grande encontrado (threshold=${THRESHOLD}). Nada a fazer."
  exit 0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="sbom_backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$ARCHIVE_DIR_ABS/$ARCHIVE_NAME"

echo "Arquivando ${#FILES[@]} arquivos SBOM para $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" "${FILES[@]}"

# Remove originals only if tar succeeded
if [ $? -eq 0 ]; then
  for f in "${FILES[@]}"; do
    echo "Removendo $SBOM_DIR_ABS/$f"
    rm -f "$SBOM_DIR_ABS/$f"
  done
  echo "Arquivamento concluído: $ARCHIVE_PATH"
else
  echo "Erro ao criar o tar.gz; originais mantidos"
  exit 1
fi
