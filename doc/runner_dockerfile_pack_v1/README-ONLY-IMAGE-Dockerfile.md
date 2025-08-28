# Runner GitHub Actions — usando só a IMAGEM + Dockerfile (config embutida)

Este pacote mostra como **usar apenas a imagem** e um **Dockerfile simples** para pré-configurar
URL/labels/nome do runner, sem precisar repetir todos os `-e` no `docker run`.

## 1) Monte sua imagem filha

Edite o `Dockerfile` se quiser alterar defaults (`REPO_URL`, `RUNNER_LABELS`, `RUNNER_NAME`)
ou passe no build:

```bash
docker build -t my/gh-runner:caixa   --build-arg REPO_URL_ARG="https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git"   --build-arg RUNNER_LABELS_ARG="self-hosted,toolbox,kind"   --build-arg RUNNER_NAME_ARG="$(hostname)-devsecops"   .
```

> Não coloque **RUNNER_TOKEN** no build — o token é secreto e expira. Passe no *run*.

## 2) Primeiro registro (precisa de token)

### Opção A — docker run
```bash
docker run -d --restart=always --name gh-runner-devsecops   -e RUNNER_TOKEN="<TOKEN_DO_RUNNER>"   -v /var/run/docker.sock:/var/run/docker.sock   -v $HOME/actions-runner:/runner   -v $HOME/.kube:/root/.kube   -v $HOME/.docker:/root/.docker   --add-host=host.docker.internal:host-gateway   my/gh-runner:caixa
```

### Opção B — docker compose (recomendado)
1) Copie `.env.example` para `.env` e preencha o **RUNNER_TOKEN**.
2) Suba o runner:
```bash
docker compose up -d
```

> Após o **primeiro registro**, com o volume `/runner` persistido, os reinícios **não precisam** do token.

## 3) Validar
- No GitHub → **Settings → Actions → Runners**: o runner deve aparecer **Online**.
- Logs: `docker logs -f gh-runner-devsecops`

## 4) Dicas
- Para usar como **runner da organização**, troque `REPO_URL` por `ORG_URL` na imagem (ou via env no compose) e gere o token no painel da **org**.
- Você pode gerar o token de registro via CLI (`gh`):
  ```bash
  export RUNNER_TOKEN=$(gh api -X POST repos/<owner>/<repo>/actions/runners/registration-token -q .token)
  docker run -e RUNNER_TOKEN="$RUNNER_TOKEN" ... my/gh-runner:caixa
  ```
- Não *bake* segredos na imagem. Tokens em camadas do Docker viram históricos recuperáveis.
