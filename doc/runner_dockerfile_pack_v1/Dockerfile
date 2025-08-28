# Child image que pré-configura o runner (sem segredos na imagem)
FROM ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest

# Escolha EXATAMENTE um destino: REPO_URL (repo) OU ORG_URL (org) OU ENTERPRISE_URL (enterprise)
# Aqui deixamos REPO_URL como padrão (pode ajustar no build com --build-arg).
ARG REPO_URL_ARG="https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git"
ARG RUNNER_LABELS_ARG="self-hosted,toolbox,kind"
ARG RUNNER_NAME_ARG="devsecops-runner"

ENV REPO_URL="${REPO_URL_ARG}"     RUNNER_LABELS="${RUNNER_LABELS_ARG}"     RUNNER_NAME="${RUNNER_NAME_ARG}"

# Observação: NÃO definimos RUNNER_TOKEN na imagem (token é efêmero e secreto).
# Passe o token no 'docker run' via variável de ambiente ou arquivo .env (compose).
