FROM ghcr.io/actions/actions-runner:latest

# --- base utils ---
USER root
# Use Bash with strict options for reliable builds
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl git jq zip unzip xz-utils sudo gnupg lsb-release apt-transport-https \
    software-properties-common build-essential pkg-config libssl-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Docker CLI + Buildx + Compose v2 ---
RUN curl -fsSL https://get.docker.com | sh \
 && docker version || true
RUN apt-get update && apt-get install -y qemu-user-static && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/lib/docker/cli-plugins \
 && curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
 -o /usr/lib/docker/cli-plugins/docker-compose \
 && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# --- kubectl + helm + kustomize + yq (versioni pinnate, no API) ---
ARG KUBECTL_VERSION=v1.30.3
ARG HELM_VERSION=3.15.2
ARG KUSTOMIZE_VERSION=5.4.2
ARG YQ_VERSION=4.44.3

# kubectl
RUN curl -fL --retry 5 --retry-delay 2 \
    -o /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
  chmod +x /usr/local/bin/kubectl && \
  kubectl version --client

# helm
RUN curl -fL --retry 5 --retry-delay 2 \
    -o /tmp/helm.tgz \
    "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" && \
  tar -xzf /tmp/helm.tgz -C /tmp && \
  mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
  rm -rf /tmp/helm.tgz /tmp/linux-amd64 && \
  helm version

# kustomize
RUN curl -fL --retry 5 --retry-delay 2 \
    -o /tmp/kustomize.tgz \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" && \
  tar -C /usr/local/bin -xzf /tmp/kustomize.tgz kustomize && \
  rm -f /tmp/kustomize.tgz && \
  kustomize version

# yq
RUN curl -fL --retry 5 --retry-delay 2 \
    -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" && \
  chmod +x /usr/local/bin/yq && yq --version

# --- Terraform + Packer ---
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update && apt-get install -y terraform packer && rm -rf /var/lib/apt/lists/*

# --- Langs & build tools ---
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs && npm i -g pnpm@latest
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv pipx && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y openjdk-17-jdk maven gradle && rm -rf /var/lib/apt/lists/*
# Install latest Go release
RUN GOVERSION=$(curl -fsSL https://go.dev/VERSION?m=text | head -n 1 | tr -d '\n') && \
  curl -fsSL "https://go.dev/dl/${GOVERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz && \
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# --- Ansible ---
RUN apt-get update && apt-get install -y ansible && rm -rf /var/lib/apt/lists/*

# Runner user già presente nell’immagine base
USER runner
