#!/usr/bin/env bash
set -euo pipefail
IMG="${IMG:-caixa-devsecops/toolbox:latest}"
NAME="${NAME:-devsecops-toolbox-ci}"

ENV_ARGS=()
[ -n "${COSIGN_PASSWORD:-}" ] && ENV_ARGS+=( -e COSIGN_PASSWORD="${COSIGN_PASSWORD}" )
[ -n "${PRD_TAG:-}" ] && ENV_ARGS+=( -e PRD_TAG="${PRD_TAG}" )
[ -n "${REGISTRY_PORT:-}" ] && ENV_ARGS+=( -e REGISTRY_PORT="${REGISTRY_PORT}" )
[ -f "$PWD/.env" ] && ENV_ARGS+=( --env-file "$PWD/.env" )

docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "[run-ci] Iniciando container CI com --network host para acesso ao kind (127.0.0.1:6443)" >&2
exec docker run --rm \
  "${ENV_ARGS[@]}" \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/work \
  -v "$HOME/.kube":/root/.kube \
  -v "$HOME/.docker":/root/.docker \
  --add-host=host.docker.internal:host-gateway \
  --workdir /work \
  --name "$NAME" \
  "$IMG" bash -lc "$*"
