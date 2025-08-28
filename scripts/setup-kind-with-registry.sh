#!/usr/bin/env bash
set -euo pipefail

REG_NAME='kind-registry'
# Porta padrão ajustada para 6201 (range reservado interno 6200-6500)
REG_PORT="${REGISTRY_PORT:-6201}"
KIND_CLUSTER='caixa-devsecops'

log() { printf "%s\n" "$*"; }

# Registry local
if docker ps -a --format '{{.Names}}' | grep -qx "${REG_NAME}"; then
  if docker ps --format '{{.Names}}' | grep -qx "${REG_NAME}"; then
    log "ℹ️  Registry '${REG_NAME}' já em execução."
  else
    log "🔄 Iniciando registry existente '${REG_NAME}'..."
    docker start "${REG_NAME}" >/dev/null
  fi
else
  log "🔧 Subindo registry ${REG_NAME} em localhost:${REG_PORT} ..."
  docker run -d --restart=always -p "0.0.0.0:${REG_PORT}:5000" --name "${REG_NAME}" registry:2
fi

# Cluster kind
if kind get clusters | grep -qx "${KIND_CLUSTER}"; then
  log "ℹ️  Cluster '${KIND_CLUSTER}' já existe; pulando criação."
else
  cat <<EOF | kind create cluster --name "${KIND_CLUSTER}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REG_PORT}"]
    endpoint = ["http://kind-registry:5000"]
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
fi

kubectl config use-context "kind-${KIND_CLUSTER}" >/dev/null 2>&1 || true

###############################################
# Kubeconfig self-heal                        #
###############################################
if [ -f /.dockerenv ]; then
  KCONF="${KUBECONFIG:-$HOME/.kube/config}"
  mkdir -p "$(dirname "$KCONF")"
  # se não houver contexto kind ou arquivo sem 'clusters:' gera novamente
  if ! grep -q "kind-${KIND_CLUSTER}" "$KCONF" 2>/dev/null || ! grep -q '^clusters:' "$KCONF" 2>/dev/null; then
    log "🔧 Gerando kubeconfig (ausente ou incompleto)."
    kind get kubeconfig --name "${KIND_CLUSTER}" >"$KCONF"
  fi
  # valida server
  SERVER_LINE=$(grep -m1 'server:' "$KCONF" | awk '{print $2}' || true)
  if [ -z "$SERVER_LINE" ]; then
    log "⚠️  kubeconfig sem server; regenerando..."
    kind get kubeconfig --name "${KIND_CLUSTER}" >"$KCONF"
    SERVER_LINE=$(grep -m1 'server:' "$KCONF" | awk '{print $2}' || true)
  fi
  # Se por algum motivo veio 0.0.0.0, substituir por 127.0.0.1 para acesso local
  if echo "$SERVER_LINE" | grep -q 'https://0.0.0.0:'; then
    sed -i 's#https://0.0.0.0:#https://127.0.0.1:#g' "$KCONF"
    SERVER_LINE=$(grep -m1 'server:' "$KCONF" | awk '{print $2}' || true)
  fi
  log "ℹ️  kubeconfig server atual: ${SERVER_LINE}"
  # Se server aponta para IP interno (ex: 172.x) e estiver inacessível, tenta regenerar para voltar a 127.0.0.1
  if echo "$SERVER_LINE" | grep -Eq 'https://172\.'; then
    if ! kubectl --request-timeout=3s get --raw=/version >/dev/null 2>&1; then
      log "⚠️  API em ${SERVER_LINE} inacessível; regenerando kubeconfig para fallback 127.0.0.1 (porta host publicada pelo kind)."
      kind get kubeconfig --name "${KIND_CLUSTER}" >"$KCONF" || true
      NEW_SERVER=$(grep -m1 'server:' "$KCONF" | awk '{print $2}' || true)
      log "ℹ️  Novo server após regeneração: ${NEW_SERVER}"
      SERVER_LINE="$NEW_SERVER"
    fi
  fi
  #########################################################
  # Auto-fix SAN mismatch: certificado gerado (cluster antigo)
  # inclui 0.0.0.0 mas não 127.0.0.1, causando erro:
  # x509: certificate is valid for ... 0.0.0.0, not 127.0.0.1
  # Estratégia: se server for 127.0.0.1 e erro aparecer, trocar
  # para IP real do control-plane (presentes nos SANs) sem recriar cluster.
  #########################################################
  if [[ "$SERVER_LINE" == https://127.0.0.1:* ]]; then
    if ! kubectl get --raw=/readyz >/dev/null 2>&1; then
      ERR_MSG=$(kubectl get --raw=/readyz 2>&1 || true)
      if echo "$ERR_MSG" | grep -q "certificate is valid" && echo "$ERR_MSG" | grep -q "not 127.0.0.1"; then
        CP_BASE="${KIND_CLUSTER}-control-plane"
        # Tentar ambos padrões de nome
        CP_IP=""
        for NAME in "$CP_BASE" "kind-$CP_BASE"; do
          if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
            CP_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$NAME" 2>/dev/null || true)
            [[ -n "$CP_IP" ]] && break
          fi
        done
        if [[ -z "$CP_IP" ]]; then
          # Fallback: extrair IP candidato da mensagem de erro (ignora 10.96.0.1 e 0.0.0.0)
            # shellcheck disable=SC2001
          CANDIDATES=$(echo "$ERR_MSG" | sed -n 's/.*valid for \([^)]*\)).*/\1/p' | tr ',' ' ')
          for IP in $CANDIDATES; do
            IP_TRIM=$(echo "$IP" | xargs)
            if [[ "$IP_TRIM" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ "$IP_TRIM" != 10.96.0.1 ]] && [[ "$IP_TRIM" != 0.0.0.0 ]]; then
              CP_IP="$IP_TRIM"; break
            fi
          done
        fi
        if [[ -n "$CP_IP" ]]; then
          log "🔧 Ajustando kubeconfig server para ${CP_IP} (SAN válido)."
          sed -i "s#https://127.0.0.1:6443#https://${CP_IP}:6443#" "$KCONF"
          SERVER_LINE="https://${CP_IP}:6443"
          log "ℹ️  Novo kubeconfig server: ${SERVER_LINE}"
        else
          log "⚠️  Não foi possível obter IP do control-plane (docker ou parsing SAN). Listando containers para debug:"
          docker ps --format '  * {{.Names}}' | sed 's/^/    /'
        fi
      fi
    fi
  fi
fi

# Esperas
log "⏳ Aguardando API server (/readyz) ficar pronto..."
ATTEMPTS=120; SLEEP=2; READY=false; i=0
while [ $i -lt $ATTEMPTS ]; do
  if kubectl get --raw="/readyz" >/dev/null 2>&1; then READY=true; break; fi
  if [ $(( i % 10 )) -eq 0 ]; then
    # mostra erro breve para debug
    ERR=$(kubectl get --raw=/readyz 2>&1 || true)
    log "  tentativa $i: ainda indisponivel (${ERR%%$'\n'*})"
  fi
  sleep $SLEEP; i=$((i+1))
done
[ "$READY" = "true" ] || {
  echo "❌ API server não ficou pronto após $((ATTEMPTS*SLEEP))s.";
  kubectl cluster-info 2>&1 || true;
  if [ "${AUTO_RECREATE:-1}" = "1" ]; then
    log "🔄 Tentando recriar cluster automaticamente (AUTO_RECREATE=1)."
    kind delete cluster --name "${KIND_CLUSTER}" || true
    # Recriação simples reutilizando config atual (sem mirror duplicado)
    cat <<EOF | kind create cluster --name "${KIND_CLUSTER}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REG_PORT}"]
    endpoint = ["http://kind-registry:5000"]
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
    kind get kubeconfig --name "${KIND_CLUSTER}" > "$KCONF" || true
    # segunda janela de espera curta
    log "⏳ Segunda espera (recriado)..."
    i=0; READY=false; ATTEMPTS2=60
    while [ $i -lt $ATTEMPTS2 ]; do
      if kubectl get --raw=/readyz >/dev/null 2>&1; then READY=true; break; fi
      sleep 2; i=$((i+1))
    done
    [ "$READY" = "true" ] || { log "❌ Falhou mesmo após recriação."; exit 1; }
    log "✅ API server disponível após recriação (${i*2}s)."
  else
    exit 1
  fi
}
log "✅ API server pronto em $((i*SLEEP))s."

if kubectl get nodes >/dev/null 2>&1; then
  log "⏳ Aguardando nós 'Ready' (180s)..."
  kubectl wait --for=condition=Ready nodes --all --timeout=180s || true
fi

log "⏳ Aguardando CoreDNS (180s)..."
kubectl -n kube-system rollout status deploy/coredns --timeout=180s \
  || kubectl -n kube-system wait --for=condition=Available deploy/coredns --timeout=180s \
  || echo "⚠️  Prosseguindo mesmo sem confirmar CoreDNS."

# Conectar registry na rede kind
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}")" = 'null' ]; then
  log "🔗 Conectando '${REG_NAME}' à rede 'kind'..."
  docker network connect "kind" "${REG_NAME}"
fi

# Namespaces + ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata: { name: des }
---
apiVersion: v1
kind: Namespace
metadata: { name: prd }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "✅ kind + registry prontos e validados (idempotente)."
