#!/usr/bin/env bash
set -euo pipefail

ns_list=(des prd)

color() { local c=$1; shift; printf "\033[%sm%s\033[0m" "$c" "$*"; }
mark_exists() { [ -f "$1" ]; }

printf "\n== PIPELINE STATUS ==\n"
for env in des prd; do
  if mark_exists pipeline-${env}.ok; then
    echo "${env^^}: $(color 32 OK) (pipeline-${env}.ok)"
  elif mark_exists pipeline-${env}.fail; then
    echo "${env^^}: $(color 31 FAIL) (pipeline-${env}.fail)"
  else
    echo "${env^^}: (sem execução registrada)"
  fi
done

printf "\n== CLUSTER RESUMO ==\n"
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl não encontrado no host -> executando dentro da toolbox..."
  IMG="${IMG:-caixa-devsecops/toolbox:latest}"
  exec docker run --rm \
    --network host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PWD":/work \
    -v "$HOME/.kube":/root/.kube \
    -v "$HOME/.docker":/root/.docker \
    --workdir /work \
    "$IMG" bash -lc './scripts/status.sh'
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Cluster inacessível."; exit 0
fi

echo "Nós:"; kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type --no-headers || true

for ns in "${ns_list[@]}"; do
  echo "\nNamespace: $ns"
  kubectl get deploy -n "$ns" -o wide 2>/dev/null || echo "(sem deploys)"
  kubectl get pods -n "$ns" -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount,AGE:.metadata.creationTimestamp 2>/dev/null || true
  # Health endpoint quick probe if service exists
  if kubectl get svc -n "$ns" quarkus-app >/dev/null 2>&1; then
    # tenta port-forward efêmero para health (usa timeout background)
    local_port=18080
    (kubectl -n "$ns" port-forward svc/quarkus-app $local_port:8080 >/dev/null 2>&1 & pid=$!; sleep 1; curl -fsS http://localhost:$local_port/q/health >/dev/null 2>&1 && echo "Health: $(color 32 UP)" || echo "Health: $(color 31 DOWN)"; kill $pid >/dev/null 2>&1 || true) || true
  fi
done

echo "\n== IMAGENS (registry local) =="
REGISTRY_PORT=${REGISTRY_PORT:-6201}
# Lista imagens que referenciam localhost:REGISTRY_PORT
if command -v docker >/dev/null 2>&1; then
  docker images --format '{{.Repository}}:{{.Tag}}' | grep "localhost:${REGISTRY_PORT}" || echo "(sem imagens)"
fi

echo "\nDica: make pipeline-jquarkus-qs-backend-des | make pipeline-jquarkus-qs-backend-prd | make status"
