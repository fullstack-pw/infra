# Use the official GitHub runner image as the base
FROM ghcr.io/actions/actions-runner:latest

# Set to non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

USER root

# Install dependencies and tools
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    jq \
    python3 \
    python3-pip \
    wget \
    unzip \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && terraform --version \
    && rm -rf /var/lib/apt/lists/*

# Install SOPS
RUN wget -O /tmp/sops.deb "https://github.com/mozilla/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb" \
    && dpkg -i /tmp/sops.deb \
    && sops --version \
    && rm /tmp/sops.deb

# Install age (for SOPS)
RUN curl -L "https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz" \
    -o /tmp/age.tar.gz \
    && mkdir -p /tmp/age-extract \
    && tar -xzf /tmp/age.tar.gz -C /tmp/age-extract \
    && mv /tmp/age-extract/age/age /usr/local/bin/age \
    && mv /tmp/age-extract/age/age-keygen /usr/local/bin/age-keygen \
    && chmod +x /usr/local/bin/age /usr/local/bin/age-keygen \
    && age --version \
    && age-keygen --version \
    && rm -rf /tmp/age-extract /tmp/age.tar.gz

# Install Docker CLI (not the daemon)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Python tools
RUN pip3 install --no-cache-dir \
    pyyaml \
    hvac \
    requests \
    boto3 \
    kubernetes

# Set up directories
RUN mkdir -p /home/runner/.kube ~/.sops/keys ~/.aws ~/.config/gcloud \
    && chown -R runner:runner /home/runner

# Add completion to bash
RUN echo 'source <(kubectl completion bash)' >> /home/runner/.bashrc \
    && echo 'source <(helm completion bash)' >> /home/runner/.bashrc \
    && echo 'alias k=kubectl' >> /home/runner/.bashrc \
    && echo 'complete -F __start_kubectl k' >> /home/runner/.bashrc \
    && chown runner:runner /home/runner/.bashrc

# Switch back to runner user
USER runner

# Set environment variables
ENV PATH="${HOME}/.local/bin:${PATH}" \
    DOCKER_BUILDKIT=1