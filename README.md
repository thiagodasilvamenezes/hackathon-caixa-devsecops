# 🏆 Desafio CAIXA 2025 — DevSecOps (Quarkus + Kubernetes no WSL)

Este projeto foi adaptado para rodar no **WSL2** (Ubuntu).

cd ..

## 🚀 Passos Rápidos
```bash
# Criar cluster local no WSL2
kind create cluster --name caixa-dev --image kindest/node:v1.29.0

# Configurar registry local acessível no WSL2
docker run -d -p 5001:5000 --restart=always --name registry registry:2

# Build da aplicação e imagem
make build-app
make image-build

# Deploy em DES
make deploy-des

# Deploy em PRD
make deploy-prd

# Testar
kubectl port-forward svc/quarkus-app -n des 8080:8080
curl http://localhost:8080/hello
```

## 🛡️ Notas WSL
- Verifique se o **Docker Desktop** tem "Use the WSL 2 based engine" habilitado.
- O registry `localhost:5001` funciona dentro do WSL e no Docker Desktop.
