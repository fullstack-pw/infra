# IMAGE_NAME: github-runner
FROM summerwind/actions-runner:latest

# Set to non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /home/runner

# Install dependencies and tools
# Use sudo to avoid permission issues
RUN sudo apt-get update && sudo apt-get install -y \
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
    && sudo rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN echo "Installing kubectl version: $KUBECTL_DL_VERSION" \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && sudo mv kubectl /usr/local/bin/

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt-get update \
    && sudo apt-get install -y terraform=${TERRAFORM_VERSION} || sudo apt-get install -y terraform \
    && terraform --version \
    && sudo rm -rf /var/lib/apt/lists/*

# Install SOPS
RUN sudo wget -O /tmp/sops.deb "https://github.com/mozilla/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb" \
    && sudo dpkg -i /tmp/sops.deb \
    && sops --version \
    && sudo rm /tmp/sops.deb

# Install age (for SOPS)
RUN sudo curl -L "https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz" \
    -o /tmp/age.tar.gz \
    && sudo mkdir -p /tmp/age-extract \
    && sudo tar -xzf /tmp/age.tar.gz -C /tmp/age-extract \
    && sudo mv /tmp/age-extract/age/age /usr/local/bin/age \
    && sudo mv /tmp/age-extract/age/age-keygen /usr/local/bin/age-keygen \
    && sudo chmod +x /usr/local/bin/age /usr/local/bin/age-keygen \
    && age --version \
    && age-keygen --version \
    && sudo rm -rf /tmp/age-extract /tmp/age.tar.gz

# Install Docker CLI (not the daemon)
RUN sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install -y docker-ce-cli \
    && sudo rm -rf /var/lib/apt/lists/*

# Install Python tools
RUN pip3 install --user --no-cache-dir \
    pyyaml \
    hvac \
    requests \
    boto3 \
    kubernetes

# Set up directories
RUN mkdir -p ~/.kube ~/.sops/keys ~/.aws ~/.config/gcloud

# Add common environment variables
ENV PATH="${HOME}/.local/bin:${PATH}" \
    DOCKER_BUILDKIT=1

# Add completion to bash
RUN echo 'source <(kubectl completion bash)' >> ~/.bashrc \
    && echo 'source <(helm completion bash)' >> ~/.bashrc \
    && echo 'alias k=kubectl' >> ~/.bashrc \
    && echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Keep the default entrypoint
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/entrypoint.sh"]