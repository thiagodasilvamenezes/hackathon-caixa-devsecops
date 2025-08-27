#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_URL="${1:?UPSTREAM_URL requerido}"
REF="${2:?REF requerido}"
SUBDIR="${3:?SUBDIR requerido}"
FORCE="${4:-0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT}/app"
META_DIR="${ROOT}/.upstream"
mkdir -p "${META_DIR}"

if [ -d "${APP_DIR}/src" ] && [ "${FORCE}" != "1" ]; then
  echo "❌ app/ já existe e FORCE!=1. Para sobrescrever: FORCE=1 make demo (ou pipeline) com FETCH=1"
  exit 1
fi

TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT

echo "⏳ Baixando quickstart ${SUBDIR} @ ${REF} de ${UPSTREAM_URL}..."
# tenta heads, tags e SHA
curl -fsSL -o "${TMP}/src.tar.gz" \
  "https://codeload.github.com/quarkusio/quarkus-quickstarts/tar.gz/refs/heads/${REF}" || \
curl -fsSL -o "${TMP}/src.tar.gz" \
  "https://codeload.github.com/quarkusio/quarkus-quickstarts/tar.gz/refs/tags/${REF}" || \
curl -fsSL -o "${TMP}/src.tar.gz" \
  "https://codeload.github.com/quarkusio/quarkus-quickstarts/tar.gz/${REF}"

tar -xzf "${TMP}/src.tar.gz" -C "${TMP}"
ROOT_DIR="$(find "${TMP}" -maxdepth 1 -type d -name 'quarkus-quickstarts-*' | head -n1)"
[ -n "${ROOT_DIR}" ] || { echo "❌ Não foi possível detectar diretório raiz no tarball"; exit 1; }

SRC_DIR="${ROOT_DIR}/${SUBDIR}"
[ -d "${SRC_DIR}" ] || { echo "❌ Subdiretório '${SUBDIR}' não existe no ref '${REF}'"; exit 1; }

# backup se já existir
if [ -d "${APP_DIR}" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  mv "${APP_DIR}" "${APP_DIR}.bak-${ts}"
fi

mkdir -p "${APP_DIR}"
rsync -a --delete "${SRC_DIR}/" "${APP_DIR}/"

echo "${UPSTREAM_URL}" > "${META_DIR}/origin.url"
echo "${REF}"          > "${META_DIR}/origin.ref"
echo "${SUBDIR}"       > "${META_DIR}/origin.subdir"

echo "✅ app/ sincronizado de ${UPSTREAM_URL}#${REF}/${SUBDIR}"
