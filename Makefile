FORCE ?= 0
FETCH ?= 0
APP_REF ?= v3.9.2
APP_SUBDIR ?= getting-started
APP_UPSTREAM_URL ?= https://github.com/quarkusio/quarkus-quickstarts
.PHONY: help toolbox-build toolbox-shell env-up env-down build-app image-build image-scan sbom sign deploy-des deploy-prd jquarkus-qs-backend-prd jquarkus-qs-backend-des pipeline-jquarkus-qs-backend-des pipeline-jquarkus-qs-backend-prd status pipeline-clean clean clean-app clean-docker-images docker-prune deep-clean clean-m2

APP_NAME ?= quarkus-getting-started
# Porta de registry movida para range interno 6200-6500 para evitar conflitos locais.
REGISTRY_PORT ?= 6201
REGISTRY ?= localhost:$(REGISTRY_PORT)
IMAGE ?= $(REGISTRY)/$(APP_NAME)
PRD_TAG ?= v1.0.0
DEV_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
STRICT ?= true

help:
	@echo "Targets:"
	@echo "  toolbox-build                     - Build toolbox image"
	@echo "  toolbox-shell                     - Open shell inside toolbox"
	@echo "  env-up                            - kind + registry + namespaces"
	@echo "  env-down                          - delete kind cluster and registry"
	@echo "  build-app                         - Maven package (fast-jar)"
	@echo "  image-build                       - Build & push image to $(REGISTRY)"
	@echo "  image-scan                        - Trivy scan (STRICT=true|false)"
	@echo "  sbom                              - Generate SBOM (Syft)"
	@echo "  sign                              - Cosign sign image"
	@echo "  deploy-des                        - Kustomize deploy to DES"
	@echo "  deploy-prd                        - Kustomize deploy to PRD"
	@echo "  jquarkus-qs-backend-des           - Full DEV flow (não bloqueia scan)"
	@echo "  jquarkus-qs-backend-prd           - Promote flow PRD (retag+scan+sbom+sign+deploy)"
	@echo "  pipeline-jquarkus-qs-backend-des  - One-shot pipeline DEV (infra+build+scan+sbom+sign+deploy DES)"
	@echo "  pipeline-jquarkus-qs-backend-prd  - One-shot pipeline PRD (build+strict scan+sbom+sign+deploy PRD)"
	@echo "  status                            - Resumo rápido de pods/deploys e resultado da pipeline"
	@echo "  pipeline-clean                    - Limpa cluster kind + registry (mesmo que env-down)"
	@echo "  clean                             - Limpeza local de artefatos (target, pipeline-*.ok/fail, containers temporários)"
	@echo "  clean-app                         - Limpa build do aplicativo (mvn clean + remove target)"
	@echo "  clean-docker-images               - Remove imagens locais criadas pelo projeto (padrão: $(APP_NAME) e $(REGISTRY))"
	@echo "  docker-prune                      - Executa 'docker system prune -af --volumes' (perigoso - use com cuidado)"
	@echo "  deep-clean                        - pipeline-clean + clean + docker-prune"
	@echo "  clean-m2                          - Remove cache Maven local (~/.m2) (manual; execute somente se souber o que faz)"
	@echo "  clean-sbom                        - Arquiva e limpa arquivos SBOM grandes em sbom/archive/"
	@echo "  archive-sbom                      - Cria um tar.gz com os SBOMs atuais em sbom/archive/ (não remove originais)"

toolbox-build:
	docker build -t caixa-devsecops/toolbox:latest -f toolbox/Dockerfile toolbox

toolbox-shell:
	./toolbox/run.sh

env-up:
	./scripts/setup-kind-with-registry.sh

env-down:
	-kind delete cluster --name caixa-devsecops
	-docker rm -f kind-registry

build-app:
	mvn -q -f app/pom.xml -DskipTests package

image-build: build-app
	docker build -f docker/Dockerfile -t $(APP_NAME):dev-$(DEV_TAG) .
	docker tag $(APP_NAME):dev-$(DEV_TAG) $(IMAGE):dev-$(DEV_TAG)
	./scripts/tag_and_push.sh $(IMAGE) dev-$(DEV_TAG)

image-scan:
	@echo "[scan] STRICT=$(STRICT)"
	STRICT=$(STRICT) ./scripts/scan.sh $(IMAGE):dev-$(DEV_TAG)

sbom:
	./scripts/sbom.sh $(IMAGE):dev-$(DEV_TAG)

sign:
	./scripts/sign.sh $(IMAGE):dev-$(DEV_TAG)

deploy-des:
	cd k8s/overlays/des && kustomize edit set image app-image=$(IMAGE):dev-$(DEV_TAG)
	kubectl apply -k k8s/overlays/des
	@echo "Run: kubectl -n des port-forward svc/quarkus-app 8080:8080"

deploy-prd:
	cd k8s/overlays/prd && kustomize edit set image app-image=$(IMAGE):$(PRD_TAG)
	kubectl apply -k k8s/overlays/prd

jquarkus-qs-backend-prd:
	@echo "Promovendo $(IMAGE):dev-$(DEV_TAG) -> $(IMAGE):$(PRD_TAG) (STRICT=$(STRICT))"
	docker pull $(IMAGE):dev-$(DEV_TAG) || true
	docker tag $(IMAGE):dev-$(DEV_TAG) $(IMAGE):$(PRD_TAG)
	./scripts/tag_and_push.sh $(IMAGE) $(PRD_TAG)
	STRICT=$(STRICT) ./scripts/scan.sh $(IMAGE):$(PRD_TAG)
	./scripts/sbom.sh $(IMAGE):$(PRD_TAG)
	./scripts/sign.sh $(IMAGE):$(PRD_TAG)
	$(MAKE) deploy-prd

jquarkus-qs-backend-des: pre-demo-fetch env-up
	$(MAKE) image-build
	STRICT=false $(MAKE) image-scan || true
	$(MAKE) sbom
	$(MAKE) sign
	$(MAKE) deploy-des
	@echo "✅ Fluxo DES concluído. Teste: kubectl -n des port-forward svc/quarkus-app 8080:8080 && curl -s http://localhost:8080/hello"


# ----- Fetch opcional do Quickstart -----
pre-demo-fetch:
	@if [ "$(FETCH)" = "1" ]; then \
	  echo "🔽 FETCH=1 → sincronizando app/ do upstream ($(APP_UPSTREAM_URL) @ $(APP_REF) / $(APP_SUBDIR))"; \
	  ./scripts/app_fetch.sh "$(APP_UPSTREAM_URL)" "$(APP_REF)" "$(APP_SUBDIR)" "$(FORCE)"; \
	else \
	  echo "ℹ️ FETCH=0 → mantendo app/ atual (sem baixar do upstream)"; \
	fi

# ----- Pipelines de um comando -----
## (removida duplicação de toolbox-build)

pipeline-jquarkus-qs-backend-des: toolbox-build
	@echo "▶️  Pipeline DEV (jquarkus-qs-backend-des): infra + build + scan/SBOM/assinatura + deploy DES"
	rm -f pipeline-des.ok pipeline-des.fail || true
	bash toolbox/run-ci.sh "FETCH=$(FETCH) APP_REF=$(APP_REF) APP_UPSTREAM_URL=$(APP_UPSTREAM_URL) APP_SUBDIR=$(APP_SUBDIR) FORCE=$(FORCE) make jquarkus-qs-backend-des && touch pipeline-des.ok || (ret=\$$?; touch pipeline-des.fail; exit \$$ret)"

pipeline-jquarkus-qs-backend-prd: toolbox-build
	@echo "▶️  Pipeline PRD (jquarkus-qs-backend-prd): build (se necessário) + scan STRICT + SBOM + assinatura + deploy PRD"
	rm -f pipeline-prd.ok pipeline-prd.fail || true
	bash toolbox/run-ci.sh "FETCH=$(FETCH) APP_REF=$(APP_REF) APP_UPSTREAM_URL=$(APP_UPSTREAM_URL) APP_SUBDIR=$(APP_SUBDIR) FORCE=$(FORCE) make jquarkus-qs-backend-des && make jquarkus-qs-backend-prd STRICT=$(STRICT) && touch pipeline-prd.ok || (ret=\$$?; touch pipeline-prd.fail; exit \$$ret)"

status:
	./scripts/status.sh

pipeline-clean:
	@echo "🧹 Limpando ambiente (cluster + registry)"
	bash toolbox/run-ci.sh 'make env-down || true'

# ----- Git hooks (local CI no commit/push) -----
hooks-install:
	git config core.hooksPath hooks
	chmod +x hooks/* || true
	@echo "✅ hooks instalados (core.hooksPath=hooks)"

# ---------------- Cleanup helpers ----------------
pipeline-clean:
	@echo "🧹 Limpando ambiente (cluster + registry)"
	bash toolbox/run-ci.sh 'make env-down || true'

clean-app:
	@echo "🧹 Limpando build do aplicativo (mvn clean + remover target)"
	-mvn -q -f app/pom.xml clean || true
	-rm -rf app/target || true

clean-docker-images:
	@echo "🧹 Removendo imagens locais criadas pelo projeto (apenas imagens nomeadas com $(APP_NAME) e $(REGISTRY))"
	-docker rmi -f $(APP_NAME):dev-$(DEV_TAG) || true
	-docker rmi -f $(IMAGE):dev-$(DEV_TAG) || true
	-# remover também a tag PRD local, se existir
	-docker rmi -f $(IMAGE):$(PRD_TAG) || true

docker-prune:
	@echo "⚠️  Executando docker system prune - af --volumes (perigoso)"
	@echo "Pressione Ctrl+C para abortar em 5s..."
	sleep 5
	-docker system prune -af --volumes || true

clean:
	@echo "🧹 Limpando artefatos locais e arquivos de pipeline"
	-rm -f pipeline-*.ok pipeline-*.fail || true
	-$(MAKE) clean-app || true
	-# remover containers temporários
	-docker rm -f $(shell docker ps -aq --filter "name=devsec-runner" ) 2>/dev/null || true

deep-clean: pipeline-clean clean docker-prune

clean-m2:
	@echo "⚠️ Removendo cache Maven (~/.m2) - use apenas se souber o que faz"
	- rm -rf ~/.m2/repository || true

clean-sbom:
	@echo "🧾 Arquivando e limpando SBOMs grandes (threshold bytes opcional: CLEAN_SBOM_THRESHOLD)"
	-chmod +x scripts/sbom-clean.sh || true
	-CLEAN_SBOM_THRESHOLD=${CLEAN_SBOM_THRESHOLD:-0} scripts/sbom-clean.sh ${CLEAN_SBOM_THRESHOLD:-0}

archive-sbom:
	@echo "🧾 Criando tar.gz com SBOMs atuais em sbom/archive (não remove originais)"
	-mkdir -p sbom/archive || true
	-TIMESTAMP=$$(date +%Y%m%d_%H%M%S) && tar -czf sbom/archive/sbom_backup_$${TIMESTAMP}.tar.gz -C sbom $(ls sbom 2>/dev/null || true) || true


