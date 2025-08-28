# 🔐 Como Obter o Token do GitHub Runner

## 📝 Instruções para obter o RUNNER_TOKEN

### 1️⃣ Acesse o seu repositório GitHub
```
https://github.com/SEU_USUARIO/SEU_REPOSITORIO
```

### 2️⃣ Navegue para Settings
- Clique em **Settings** (na aba do repositório)
- No menu lateral, clique em **Actions**
- Clique em **Runners**

### 3️⃣ Criar novo runner
- Clique em **New self-hosted runner**
- Escolha **Linux** como sistema operacional
- Copie o **token** que aparece no comando

### 4️⃣ Usar o token
- Substitua `SEU_TOKEN_DO_GITHUB` nos comandos pelos token copiado
- **OU** edite o arquivo [`tokenGithub.txt`](tokenGithub.txt) com seu token

## ⚠️ Importante - Segurança

- **NÃO commite** tokens reais em repositórios públicos
- **Use** tokens apenas localmente ou em secrets do CI/CD
- **Revogue** tokens que não usar mais em Settings → Developer settings → Personal access tokens

## 📋 Exemplo de uso

```bash
# Substitua SEU_TOKEN_AQUI pelo token real
docker run -d --restart=always --name gh-runner-devsecops \
  -e RUNNER_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx" \
  # ... resto do comando
```

## 🔄 Alternativas Seguras

1. **Variável de ambiente**: `export RUNNER_TOKEN="seu_token"`
2. **Arquivo local** (não comitado): `.env` ou arquivo temporário
3. **GitHub Secrets**: Para workflows automatizados
