# Use Ubuntu as the base image
FROM ubuntu:22.04

# Set environment variables
ENV RUNNER_VERSION=2.321.0 \
    RUNNER_HOME=/actions-runner \
    DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    sudo \
    ca-certificates \
    tar \
    unzip \
    libssl-dev \
    gpg \
    wget \
    lsb-release \
    && apt-get clean

# Create a non-root user to run the runner
RUN useradd -m runner

# Switch to the runner home directory
WORKDIR ${RUNNER_HOME}

# Download and verify the GitHub Actions Runner package
RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && echo "ba46ba7ce3a4d7236b16fbe44419fb453bc08f866b24f04d549ec89f1722a29e  actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | sha256sum -c \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && rm -f actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

#VAULT
RUN wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
RUN    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
RUN    sudo apt update && sudo apt install vault

# Add runner script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set ownership for the runner
RUN chown -R runner:runner ${RUNNER_HOME}

RUN sudo ./bin/installdependencies.sh

# Switch to the non-root user
USER runner

# Define the default entrypoint
ENTRYPOINT ["/entrypoint.sh"]
