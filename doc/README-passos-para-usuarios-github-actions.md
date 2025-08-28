# 🚀 CAIXA DevSecOps — GitHub Actions CI/CD

**Automatize suas pipelines DES/PRD** usando **GitHub Actions** com **runner containerizado**

> 🎯 **Para quem?** Times que querem CI/CD automático sem instalar ferramentas localmente

## 📋 O que você vai conseguir

✅ **Pipeline automática** → Dispara no push ou manualmente  
✅ **Ambientes isolados** → DES (desenvolvimento) e PRD (produção)  
✅ **Zero setup** → Tudo roda em containers  
✅ **Artefatos seguros** → SBOMs, relatórios de scan, logs  

## 🔗 Recursos Necessários

- **Repositório:** https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git
- **Imagem runner:** `ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest`
- **Host com Docker** (4 vCPUs + 8GB RAM recomendado)

**O runner já inclui:** Docker CLI, kind, kubectl, kustomize, Maven/Java 17, Trivy, Syft, Cosign

---

## 🛠️ Setup Inicial (5 minutos)

### 1️⃣ Preparar o host

**Linux/WSL:**
- ✅ Docker instalado e rodando
- ✅ Portas livres: `6201` (registry) + range `6200–6500`

**Windows (Docker Desktop):**
- ✅ Docker Desktop com WSL2 habilitado
- ✅ Compartilhamento de arquivos ativo

### 2️⃣ Obter token do runner

1. Vá em **Settings → Actions → Runners → New self-hosted runner**
2. Copie o **token** que aparece
3. ⚠️ **NUNCA** compartilhe este token!

### 3️⃣ Subir o runner

**Linux/WSL/macOS:**
```bash
docker run -d --restart=always --name gh-runner-devsecops \
  -e REPO_URL="https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git" \
  -e RUNNER_NAME="$(hostname)-devsecops" \
  -e RUNNER_LABELS="self-hosted,toolbox,kind" \
  -e RUNNER_TOKEN="SEU_TOKEN_AQUI" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $HOME/actions-runner:/runner \
  -v $HOME/.kube:/root/.kube \
  -v $HOME/.docker:/root/.docker \
  --add-host=host.docker.internal:host-gateway \
  ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest
```

**Windows (PowerShell):**
```powershell
docker run -d --restart=always --name gh-runner-devsecops `
  -e REPO_URL="https://github.com/thiagodasilvamenezes/hackathon-caixa-devsecops.git" `
  -e RUNNER_NAME="$($env:COMPUTERNAME)-devsecops" `
  -e RUNNER_LABELS="self-hosted,toolbox,kind" `
  -e RUNNER_TOKEN="SEU_TOKEN_AQUI" `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "$env:USERPROFILE\actions-runner:/runner" `
  -v "$env:USERPROFILE\.kube:/root/.kube" `
  -v "$env:USERPROFILE\.docker:/root/.docker" `
  --add-host=host.docker.internal:host-gateway `
  ghcr.io/thiagodasilvamenezes/caixa-devsecops-hackathon/runner:latest
```

> 📝 **Sobre o RUNNER_TOKEN**: 
> - **Arquivo**: [`tokenGithub.txt`](../tokenGithub.txt) contém placeholder - substitua pelo seu token
> - **Como obter**: GitHub → Settings → Actions → Runners → New self-hosted runner  
> - **⚠️ Segurança**: Nunca commite tokens reais em repositórios públicos

### 4️⃣ Verificar se funcionou

1. Vá em **Settings → Actions → Runners**
2. Deve aparecer **🟢 Online** com labels `self-hosted, toolbox, kind`

---

## ⚙️ Configurar Secrets (Obrigatório)

Vá em **Settings → Secrets and variables → Actions**

### 🔐 Secrets (informações sensíveis)
- **`COSIGN_PASSWORD`** → Senha para assinatura digital (ex: `hackathon2025`)
- **`GHCR_TOKEN`** → Token GitHub para acessar imagens (opcional se imagem for pública)

### 📊 Variables (configurações)
- **`STRICT`** → `true` (falha em CVEs) ou `false` (apenas alerta)
- **`PRD_TAG`** → Tag de produção (ex: `v1.0.0`)

**Como criar:**
1. **New repository secret** → Nome: `COSIGN_PASSWORD`, Valor: sua senha
2. **New repository variable** → Nome: `STRICT`, Valor: `true`

---

## 🚀 Como Usar (Super Simples)

### 🔧 Pipeline DES (Desenvolvimento)

1. Vá em **Actions → DEV Pipeline (DES)**
2. Click **Run workflow**
3. Escolha as opções:
   - **`fetch`** → `false` (usa código do repo) ou `true` (baixa Quarkus oficial)
   - **`app_ref`** → `v3.9.2` (se fetch=true)
4. Click **Run workflow** ✅

### 🚀 Pipeline PRD (Produção)

1. **Primeiro rode DES** (acima) ✅
2. Vá em **Actions → Promote to PRD**
3. Click **Run workflow**
4. Configure:
   - **`prd_tag`** → `v1.0.0` (ou sua versão)
   - **`strict`** → `true` (recomendado para PRD)
5. Click **Run workflow** ✅

### 🧹 Limpeza (Se der problema)

1. Vá em **Actions → Clean Environment**
2. Click **Run workflow** → **Run workflow**
3. Isso remove cluster e registry local

---

## 📁 Download dos Resultados

Após cada execução, baixe os **artifacts**:

- **📊 des-status** → Status DES, portas, health, logs
- **📊 prd-status** → Status PRD, portas, health, logs  
- **📋 sbom-reports** → Inventário de componentes
- **🛡️ security-scans** → Relatórios de vulnerabilidades

**Como baixar:**
1. Click na execução completada
2. Scroll até **Artifacts**
3. Click para download

---

## 🔍 O que acontece nos bastidores

**Pipeline DES:**
1. 🏗️ Cria cluster Kubernetes local (kind)
2. 📦 Sobe registry local (porta 6201) 
3. 🔨 Compila aplicação Quarkus (Java 17 + Maven)
4. 🐳 Build da imagem Docker
5. 🛡️ Scan de segurança (Trivy)
6. 📋 Gera SBOM (inventário de componentes)
7. ✍️ Assina imagem digitalmente (Cosign)
8. 🚀 Deploy no ambiente DES
9. 📊 Gera relatórios e aloca portas (6200-6500)

**Pipeline PRD:**
- Promove tag DES → PRD
- Scan **rigoroso** (falha em CVEs se STRICT=true)
- Deploy no ambiente PRD isolado

---

## ❓ Troubleshooting

### 🔴 Runner aparece Offline
```bash
# Verificar se está rodando
docker ps | grep gh-runner-devsecops

# Ver logs
docker logs gh-runner-devsecops

# Restartar se necessário
docker restart gh-runner-devsecops
```

### 🔴 Erro de porta ocupada
- **6201 ocupada**: Libere a porta ou pare outros registries Docker
- **Range 6200-6500**: Os scripts encontram portas livres automaticamente

### 🔴 Pipeline falha no Trivy (CVEs)
- **Solução temporária**: Use `strict = false` no workflow
- **Solução definitiva**: Atualize dependências da aplicação

### 🔴 Problemas de rede/firewall
- **Windows**: Permita Docker Desktop no firewall
- **Linux**: Verifique iptables se usar firewall restritivo

### 🔴 Token inválido
- Regenere o token em **Settings → Actions → Runners**
- Atualize a variável `RUNNER_TOKEN` e recrie o container

---

## 🎯 Próximos Passos

Após dominar o básico:

- [ ] 🔄 **Auto-trigger** → Configure push automático
- [ ] 🌐 **Acesso externo** → Configure Ingress/NodePort  
- [ ] 📊 **Dashboards** → Integre com Grafana/Prometheus
- [ ] 🔒 **Segurança** → Configure políticas OPA/Gatekeeper
- [ ] 🚀 **Multi-cluster** → Expanda para ambientes remotos

---

## 📚 Links Úteis

- 📖 **Documentação principal**: `../README.md`
- 🐳 **Execução local**: Use `make` diretamente
- 🪟 **Windows específico**: `WINDOWS-DOCKER-DESKTOP-GUIDE.md`
- 🔧 **Customização**: Edite workflows em `.github/workflows/`

---

**🎉 Pronto! Agora você tem CI/CD automático para DevSecOps**

> 💡 **Dica**: Execute DES primeiro, verifique os artifacts, depois promova para PRD
