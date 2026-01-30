FROM ghcr.io/actions/actions-runner:latest

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \

&& curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \

&& curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \

&& curl -fsSL https://get.opentofu.org/opentofu.gpg | gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg \
    && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --dearmor -o /usr/share/keyrings/opentofu-repo-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg,/usr/share/keyrings/opentofu-repo-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | tee /etc/apt/sources.list.d/opentofu.list \

&& curl -L "https://github.com/mozilla/sops/releases/download/v3.8.1/sops_3.8.1_amd64.deb" -o /tmp/sops.deb\
    && dpkg -i /tmp/sops.deb \
    && sops --version \
    && rm /tmp/sops.deb \

&& curl -L "https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz" \
    -o /tmp/age.tar.gz \
    && mkdir -p /tmp/age-extract \
    && tar -xzf /tmp/age.tar.gz -C /tmp/age-extract \
    && mv /tmp/age-extract/age/age /usr/local/bin/age \
    && mv /tmp/age-extract/age/age-keygen /usr/local/bin/age-keygen \
    && chmod +x /usr/local/bin/age /usr/local/bin/age-keygen \
    && age --version \
    && age-keygen --version \
    && rm -rf /tmp/age-extract /tmp/age.tar.gz \

&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \

&& apt-get update \
    && apt-get install -y \
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
    make \
    python3 \
    python3-venv \
    gettext-base \
    helm \
    terraform \
    vault \
    tofu \
    docker-ce-cli \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \

&& mkdir -p /home/runner/.kube /home/runner/.sops/keys /home/runner/.aws /home/runner/.config/gcloud \
    && chown -R runner:runner /home/runner \
    && setcap -r /usr/bin/vault

USER runner

RUN echo 'source <(kubectl completion bash)' >> /home/runner/.bashrc \
    && echo 'source <(helm completion bash)' >> /home/runner/.bashrc \
    && echo 'alias k=kubectl' >> /home/runner/.bashrc \
    && echo 'complete -F __start_kubectl k' >> /home/runner/.bashrc \

&& python3 -m venv ./python-venv \
    && . ./python-venv/bin/activate \
    && pip3 install \
    pyyaml \
    hvac \
    requests \
    boto3 \
    kubernetes \
    ansible

ENV PATH="${HOME}/.local/bin:${PATH}" \
    DOCKER_BUILDKIT=1