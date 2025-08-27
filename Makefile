SHELL := /bin/bash
APP_NAME ?= quarkus-getting-started
REGISTRY ?= localhost:5001
IMAGE := $(REGISTRY)/$(APP_NAME)
SHORT_SHA ?= $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo "dev")
DEV_TAG := dev-$(SHORT_SHA)
PRD_TAG ?= v0.1.0

build-app:
	mvn -f app/pom.xml -DskipTests package

image-build:
	docker build -f docker/Dockerfile -t $(APP_NAME):$(DEV_TAG) .
	docker tag $(APP_NAME):$(DEV_TAG) $(IMAGE):$(DEV_TAG)
	docker push $(IMAGE):$(DEV_TAG)

deploy-des:
	kubectl apply -f <(sed 's/placeholder/des/g' k8s/base/namespace.yaml)
	kubectl apply -k k8s/overlays/des

deploy-prd:
	kubectl apply -f <(sed 's/placeholder/prd/g' k8s/base/namespace.yaml)
	kubectl apply -k k8s/overlays/prd
