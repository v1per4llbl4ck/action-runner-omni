# Dockerfile
FROM ghcr.io/actions/actions-runner:latest

# --- base utils ---
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl git jq zip unzip xz-utils sudo gnupg lsb-release apt-transport-https \
    software-properties-common build-essential pkg-config libssl-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Docker CLI + Buildx + Compose v2 ---
RUN curl -fsSL https://get.docker.com | sh \
 && docker version || true
# Buildx già incluso con Docker; abilita qemu per multi-arch se vuoi:
RUN apt-get update && apt-get install -y qemu-user-static && rm -rf /var/lib/apt/lists/*
# Compose plugin
RUN mkdir -p /usr/lib/docker/cli-plugins \
 && curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
 -o /usr/lib/docker/cli-plugins/docker-compose \
 && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# --- kubectl + helm + kustomize + yq ---
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl
RUN curl -L https://get.helm.sh/helm-$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)-linux-amd64.tar.gz \
 | tar xz && mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64
RUN curl -L https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_linux_amd64.tar.gz \
 | tar xz -C /usr/local/bin
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq

# --- Terraform + Packer ---
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update && apt-get install -y terraform packer && rm -rf /var/lib/apt/lists/*

# --- Langs & build tools (Node, Python, Java, Go, .NET, Rust) ---
# Node 20 + pnpm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y nodejs && npm i -g pnpm@latest
# Python 3 + pipx + venv
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv pipx && rm -rf /var/lib/apt/lists/*
# Java 17 + Maven + Gradle
RUN apt-get update && apt-get install -y openjdk-17-jdk maven gradle && rm -rf /var/lib/apt/lists/*
# Go
RUN curl -L https://go.dev/dl/$(curl -s https://go.dev/VERSION?m=text).linux-amd64.tar.gz \
 | tar -C /usr/local -xz && echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
# .NET 8 SDK
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O /tmp/msprod.deb \
 && dpkg -i /tmp/msprod.deb && rm /tmp/msprod.deb \
 && apt-get update && apt-get install -y dotnet-sdk-8.0 && rm -rf /var/lib/apt/lists/*
# Rust (non-interattivo)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# --- Cloud CLIs (AWS/GCP/Azure) ---
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
 && unzip /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
   > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && apt-get update && apt-get install -y google-cloud-cli && rm -rf /var/lib/apt/lists/*
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# --- SecDevOps utils ---
RUN curl -L https://github.com/aquasecurity/trivy/releases/latest/download/trivy_$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r '.tag_name' | tr -d v)_Linux-64bit.deb \
 -o /tmp/trivy.deb && apt-get update && apt-get install -y /tmp/trivy.deb && rm /tmp/trivy.deb
RUN curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
 -o /usr/local/bin/hadolint && chmod +x /usr/local/bin/hadolint
RUN apt-get update && apt-get install -y shellcheck skopeo && rm -rf /var/lib/apt/lists/*
# cosign
RUN curl -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
 -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign

# --- Ansible ---
RUN apt-get update && apt-get install -y ansible && rm -rf /var/lib/apt/lists/*

# Runner user già presente nell’immagine base
USER runner
