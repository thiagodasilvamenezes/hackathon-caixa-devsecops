
# Guia — Execução com **Docker Desktop para Windows** (DevSecOps + kind)

Este guia mostra como rodar **toda a pipeline local** (toolbox + kind + Quarkus + scan/SBOM/assinatura + DES/PRD) usando **Docker Desktop para Windows**, **sem** precisar instalar `kubectl`/`kind`/`make` no host. Também inclui a opção de subir um **runner do GitHub Actions**.

> **Portas padrão (atualizado):** range reservado **6200–6500**.  
> - Registry local: **localhost:6201** (ajustável via `REGISTRY_PORT`)  
> - Port-forward HTTP (DES/PRD): portas do mesmo range (alocadas quando necessário).

---

## 1) Preparar o Docker Desktop

1. Instale/abra o **Docker Desktop** (Windows 10/11).  
2. *Settings → General*: marque **Use the WSL 2 based engine**.  
3. *Settings → Resources → WSL Integration*: habilite sua distro (ex.: **Ubuntu**).  
4. *Settings → Resources → File sharing*: garanta que `C:\Users\<SEU_USUARIO>` está compartilhado (padrão).  
5. Caso o Windows solicite, permita o firewall para a porta **6201** (registry) e para portas de *port-forward*.

> Dica: mantenha o projeto em `C:\Users\<você>\...` ou em `\\wsl$\Ubuntu\home\<você>\...`.

---

## 2) Obter o projeto

**Opção A — Clonar repo (recomendado)**  
Abra **PowerShell** e rode:
```powershell
git clone https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git
cd hackathon-caixa-devsecops
```

**Opção B — Já tem o projeto**  
Apenas `cd` para o diretório onde o projeto está.

---

## 3) Rodar *dentro da toolbox* (modo interativo)

O comando abaixo inicia a **toolbox** (container com kubectl/kind/trivy/syft/cosign/make) usando o **engine do Docker Desktop**. Seu diretório atual é montado em `/work`.

```powershell
docker run --rm -it `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "${PWD}:/work" `
  -v "$env:USERPROFILE\.kube:/root/.kube" `
  -v "$env:USERPROFILE\.docker:/root/.docker" `
  --add-host=host.docker.internal:host-gateway `
  --workdir /work `
  --name devsecops-toolbox `
  caixa-devsecops/toolbox:latest
```

> No prompt `root@...:/work#`, execute os alvos **make** abaixo.

### 3.1 Pipeline DEV completa (DES)
```bash
# Variáveis opcionais:
export REGISTRY_PORT=6201            # porta do registry (default 6201)
export STRICT=true                   # falhar em CVEs altos/crit
export PRD_TAG=v1.0.0                # tag estável
export COSIGN_PASSWORD='minha-senha' # evita prompt ao assinar

make pipeline-jquarkus-qs-backend-des
make status
```

### 3.2 Testar aplicação (DES)
Em outro terminal (dentro ou fora do container):
```bash
kubectl -n des port-forward svc/quarkus-app 8080:8080 &
curl -s http://localhost:8080/hello
curl -s http://localhost:8080/q/health
```

### 3.3 Promover para PRD
```bash
make pipeline-jquarkus-qs-backend-prd STRICT=true
make status
```

### 3.4 Limpeza total
```bash
make env-down
```

---

## 4) Rodar **sem** entrar na toolbox (um tiro só)

Dispare a pipeline diretamente do **PowerShell** (a toolbox executa e sai):
```powershell
docker run --rm `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "${PWD}:/work" `
  -v "$env:USERPROFILE\.kube:/root/.kube" `
  -v "$env:USERPROFILE\.docker:/root/.docker" `
  --add-host=host.docker.internal:host-gateway `
  --workdir /work `
  --name devsecops-ci `
  caixa-devsecops/toolbox:latest `
  bash -lc "make pipeline-jquarkus-qs-backend-des && make status"
```

### 4.1 Usando **app-fetch** (código oficial Quarkus Quickstart)
```powershell
docker run --rm `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "${PWD}:/work" `
  -v "$env:USERPROFILE\.kube:/root/.kube" `
  -v "$env:USERPROFILE\.docker:/root/.docker" `
  --add-host=host.docker.internal:host-gateway `
  --workdir /work `
  caixa-devsecops/toolbox:latest `
  bash -lc "FETCH=1 APP_REF=v3.9.2 make pipeline-jquarkus-qs-backend-des"
```

---

## 5) (Opcional) Runner do GitHub Actions no Docker Desktop

> **Token é obrigatório no primeiro registro** (repo/org). Depois, com o volume `/runner` persistido, reinícios **não** pedem token.

```powershell
docker run -d --restart=always --name gh-runner-devsecops `
  -e REPO_URL="https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git" `
  -e RUNNER_NAME="$($env:COMPUTERNAME)-devsecops" `
  -e RUNNER_LABELS="self-hosted,toolbox,kind" `
  -e RUNNER_TOKEN="<TOKEN_DO_RUNNER>" `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "$env:USERPROFILE\actions-runner:/runner" `
  -v "$env:USERPROFILE\.kube:/root/.kube" `
  -v "$env:USERPROFILE\.docker:/root/.docker" `
  --add-host=host.docker.internal:host-gateway `
  ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest
```
Depois, execute os **workflows** na aba *Actions* do GitHub (DEV/PRD/Clean).

---

## 6) Variáveis úteis (Makefile/ambiente)

| Variável         | Default         | Uso |
|------------------|-----------------|-----|
| `REGISTRY_PORT`  | `6201`          | Porta do registry local (range **6200–6500**) |
| `REGISTRY`       | `localhost:$(REGISTRY_PORT)` | Endpoint base do registry |
| `APP_NAME`       | `quarkus-getting-started` | Nome lógico da imagem local |
| `PRD_TAG`        | `v1.0.0`        | Tag de produção |
| `STRICT`         | `true`          | Gating de severidade (Trivy) |
| `COSIGN_PASSWORD`| (vazio)         | Senha da chave Cosign |

Exemplos:
```bash
# Dentro da toolbox:
REGISTRY_PORT=6205 STRICT=false make pipeline-jquarkus-qs-backend-des
PRD_TAG=v2.0.0 make pipeline-jquarkus-qs-backend-prd
```

---

## 7) Troubleshooting (Windows)

| Sintoma | Causa provável | Ação |
|--------|-----------------|------|
| Erro TLS x509 127.0.0.1 vs 0.0.0.0 | kubeconfig antigo | `make env-down` e rerodar pipeline; toolbox ajusta para `host.docker.internal` |
| Porta 6201 ocupada | conflito local | `REGISTRY_PORT=62xx make pipeline-jquarkus-qs-backend-des` |
| Cosign pedindo senha | senha não exportada | `export COSIGN_PASSWORD=...` antes do make |
| `kubectl` não instalado | ambiente limpo | `make status` (fallback) ou `make toolbox-shell` |
| Roteamento/Firewall | primeira execução | permita o firewall do Windows para registry e port-forward |

---

## 8) Referências
- Repositório (scripts/Makefiles): https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git
- Runner GHCR: `ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest`
- Quarkus Quickstart (Temurin 17)
