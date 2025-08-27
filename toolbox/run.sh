#!/usr/bin/env bash
set -euo pipefail

IMG="${IMG:-caixa-devsecops/toolbox:latest}"
NAME="${NAME:-devsecops-toolbox}"

# Monta variaveis de ambiente (host + .env)
ENV_ARGS=()
[ -n "${COSIGN_PASSWORD:-}" ] && ENV_ARGS+=( -e COSIGN_PASSWORD="${COSIGN_PASSWORD}" )
[ -f "$PWD/.env" ] && ENV_ARGS+=( --env-file "$PWD/.env" )

echo "[toolbox] Limpando container anterior (idempotente): $NAME"
docker rm -f "$NAME" >/dev/null 2>&1 || true

echo "[toolbox] Iniciando container:\n  Image: $IMG\n  Name : $NAME"
[ ${#ENV_ARGS[@]} -gt 0 ] && echo "  Env   : ${ENV_ARGS[*]}"

docker run --rm -it \
  --network host \
  --add-host=host.docker.internal:host-gateway \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/work \
  -v "$HOME/.kube":/root/.kube \
  -v "$HOME/.docker":/root/.docker \
  --workdir /work \
  --name "$NAME" \
  --entrypoint /bin/bash \
  "${ENV_ARGS[@]}" \
  "$IMG" "$@"
