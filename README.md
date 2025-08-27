# Hackathon CAIXA 2025 – DevSecOps (Toolbox + kind)

Pipeline local para build e deploy de um app **Quarkus** (Temurin 17) em **Kubernetes (kind)** com **dois ambientes**: **DES** e **PRD**.
Inclui camadas de DevSecOps: **Trivy** (scan), **Syft** (SBOM) e **Cosign** (assinatura).

## Requisitos no host (WSL)
- Docker funcional (sem necessidade de Docker Desktop).
- (Opcional) `make` no host para rodar `make toolbox-shell`.

## Passo a passo
```bash
# 1) Buildar a toolbox com todas as ferramentas
make toolbox-build

# 2) Entrar na toolbox (container de ferramentas)
make toolbox-shell

# 3) Executar a pipeline local completa para DES
make demo

# 4) Testar
kubectl -n des port-forward svc/quarkus-app 8080:8080
curl -s http://localhost:8080/hello

# 5) Promover para PRD (tag estável) com Trivy estrito
make promote-to-prd STRICT=true
kubectl -n prd get deploy,svc,pods
```

### Variáveis (podem ser sobrescritas)
- `REGISTRY` (padrão: `localhost:5001`)
- `APP_NAME` (padrão: `quarkus-getting-started`)
- `PRD_TAG` (padrão: `v0.1.0`)
- `STRICT` (`true|false` — controla Trivy)

Exemplo:
```bash
REGISTRY=localhost:5001 APP_NAME=meuapp make demo
```

### Cosign (evitar prompt)
- **Sem senha (demo):** não exporte nada; a chave será gerada sem senha.
- **Com senha:** defina `COSIGN_PASSWORD` antes do `make sign`/`make demo`.

```bash
export COSIGN_PASSWORD='minha-senha'
make demo
```

## Estrutura
```
app/                      # código Quarkus (Hello + health)
docker/Dockerfile         # multistage (Maven -> Temurin 17 JRE)
k8s/base, overlays/des,prd# manifests via kustomize (dois ambientes)
scripts/                  # setup kind/registry, scan, sbom, sign, push
toolbox/                  # imagem com kubectl/kind/kustomize/trivy/syft/cosign
Makefile                  # pipeline local (alvos: demo, promote-to-prd, etc.)
```
