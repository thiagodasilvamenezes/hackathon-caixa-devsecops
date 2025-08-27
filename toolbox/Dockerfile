FROM maven:3.9-eclipse-temurin-17
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release \
    make jq unzip rsync git tar xz-utils \
    iproute2 iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI estático
ARG ARCH=amd64
RUN set -eux; \
    case "$ARCH" in \
      amd64) ARCH_DL=x86_64 ;; \
      arm64) ARCH_DL=aarch64 ;; \
      *) ARCH_DL=x86_64 ;; \
    esac; \
    curl -fsSL -o /tmp/docker.tgz "https://download.docker.com/linux/static/stable/${ARCH_DL}/docker-27.1.1.tgz"; \
    tar -xz -C /usr/local/bin --strip-components=1 -f /tmp/docker.tgz docker/docker; \
    rm -f /tmp/docker.tgz

# kubectl
RUN set -eux; K_VER="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"; \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${K_VER}/bin/linux/amd64/kubectl"; \
    install -m 0755 kubectl /usr/local/bin/kubectl; rm -f kubectl

# kind
RUN curl -Lo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64" && chmod +x /usr/local/bin/kind

# kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
    install -m 0755 kustomize /usr/local/bin/kustomize && rm -f kustomize

# trivy, syft, cosign
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin && \
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin && \
    curl -sSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64" && chmod +x /usr/local/bin/cosign

WORKDIR /work
