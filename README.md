# infra

This repository contains the infrastructure-as-code and cluster configurations for the **fullstack.pw** homelab environment. The environment runs multiple Kubernetes clusters (sandbox, dev, stg, prod, runners) and supporting services like DNS, ingress controllers, certificate management, etc.

## Overview

The main goals of this repository are:

- **Centralized Configuration**: Keep all infrastructure code in one place for consistent management and version control.
- **Homelab Kubernetes**: Manage multiple K3s and vanilla Kubernetes clusters on Proxmox VMs.
- **CI/CD Integration**: Provide GitHub and GitLab pipelines (via self-hosted runners) to automate builds and deployments.
- **Support Services**: Set up DNS, ingress, certificates, vault-based secret management, and more.

## Repository Structure

The repository follows a modular, DRY (Don't Repeat Yourself) approach to infrastructure code:

```
infra/
├── clusters/              # Kubernetes cluster configurations
│   ├── modules.tf         # Module instances for each cluster
│   ├── variables.tf       # Cluster-specific variables
│   ├── providers.tf       # Provider configurations
│   ├── outputs.tf         # Cluster outputs
│   ├── backend.tf         # Remote state configuration
│   ├── imports.tf         # Resource import definitions
│   └── moved.tf           # Resource move tracking
├── modules/               # Reusable Terraform modules
│   ├── base/              # Base modules (composable building blocks)
│   │   ├── credentials/   # Secret management
│   │   ├── helm/          # Standardized Helm releases
│   │   ├── ingress/       # Ingress configurations
│   │   ├── monitoring/    # Monitoring configurations
│   │   ├── namespace/     # Namespace management
│   │   ├── persistence/   # PVC configurations
│   │   └── values-template/ # Template rendering
│   └── apps/              # Application modules (composed from base modules)
│       ├── certmanager/   # Certificate management
│       ├── externaldns/   # DNS management
│       ├── external-secrets/ # External secret management
│       ├── github-runner/ # GitHub Actions runners
│       ├── gitlab-runner/ # GitLab CI runners
│       ├── ingress-nginx/ # NGINX ingress controller
│       ├── minio/         # S3-compatible storage
│       ├── nats/          # NATS messaging
│       ├── observability/ # Observability stack
│       ├── otel-collector/ # OpenTelemetry collector
│       ├── postgres/      # PostgreSQL database
│       ├── redis/         # Redis database
│       ├── registry/      # Docker registry
│       └── vault/         # HashiCorp Vault
├── proxmox/               # Proxmox VM configurations
│   ├── main.tf            # VM provisioning logic
│   ├── variables.tf       # Proxmox-specific variables
│   ├── providers.tf       # Provider configurations
│   ├── outputs.tf         # Proxmox outputs
│   ├── scripts/           # VM configuration scripts
│   ├── playbooks/         # Ansible playbooks for VM configuration
│   └── vms/               # VM configuration files
└── .github/workflows/     # GitHub Actions workflows
    ├── ansible.yml        # Ansible provisioning workflow
    ├── terraform-plan.yml # Terraform plan workflow
    └── terraform-apply.yml # Terraform apply workflow
```

## Module Design Philosophy

Our infrastructure follows these key principles:

1. **Composability**: Base modules are designed to be composed together to create more complex application modules.
2. **Standardization**: Common patterns (namespaces, Helm releases, etc.) are implemented consistently.
3. **DRY (Don't Repeat Yourself)**: Common configuration is centralized and reused.
4. **Separation of Concerns**: Each module focuses on a specific responsibility.

### Base Modules

Base modules provide fundamental building blocks that can be composed to create more complex modules:

- **namespace**: Standardized namespace creation and management
- **helm**: Consistent Helm chart deployment
- **values-template**: Standardized template rendering for Helm values
- **ingress**: Common ingress configuration
- **persistence**: Standard persistent volume claim management
- **credentials**: Secret management and generation
- **monitoring**: Standardized monitoring configurations

### Application Modules

Application modules compose base modules to create complete application deployments:

```terraform
module "namespace" {
  source = "../../base/namespace"
  # ...
}

module "credentials" {
  source = "../../base/credentials"
  # ...
}

module "values" {
  source = "../../base/values-template"
  # ...
}

module "helm" {
  source = "../../base/helm"
  # ...
}

module "ingress" {
  source = "../../base/ingress"
  # ...
}
```

## High-Level Architecture

### Cloudflare

- Manages DNS for `fullstack.pw` and provides a CDN and WAF.
- `cert-manager` in each cluster handles ACME certificate issuance via DNS challenges to Cloudflare.

### Homelab / Proxmox

- Two physical nodes:
  - **NODE01** (Acer Nitro, i7-4710HQ, 16GB)
  - **NODE02** (HP ED800 G3 Mini, i7-7700T, 32GB)
- Proxmox hosts multiple VMs:
  - **Internal DNS** (authoritative for `fullstack.pw` inside homelab)
  - **HAProxy** VM at `k8s.fullstack.pw` (load balancer for the Kubernetes clusters)
  - **K8s Clusters**:
    - **Sandbox** (vanilla K8s) on VMs `k01`, `k02`, `k03`
    - **Dev** (K3s) on VM `k8s-dev`
    - **Stg** (K3s) on VM `k8s-stg`
    - **Prod** (K3s) on VM `k8s-prod`
    - **Tools** (K3s) on VM `k8s-tools`

### Lenovo Legion (Personal Laptop)

- **Rancher Desktop** installed, running a **runners** cluster (K3s) for pipelines.
- Not running Proxmox, but considered part of the homelab environment because it can spin up ephemeral runners to execute CI jobs.

### Kubernetes (K3s / Vanilla) Clusters

- Common add-ons across clusters:
  - **cert-manager**, **external-dns**, **external-secrets**, **nginx-ingress**, **metalLB**, **local-path-provisioner**.
- Storage and services: **MinIO** (`s3.fullstack.pw`), **private registry** (`registry.fullstack.pw`), **Vault** (`vault.fullstack.pw`).
- Example application: **API User Management** (`dev.api-usermgmt.fullstack.pw`, `stg.api-usermgmt.fullstack.pw`, `api-usermgmt.fullstack.pw`).

### CI/CD Integrations

- **GitHub**: `actions-runner-controller` runs on the Rancher Desktop cluster to register self-hosted GitHub Actions runners.
- **GitLab**: A separate `gitlab-runner` is deployed on K3s to run GitLab CI jobs.

## Observability Stack

The infrastructure includes a comprehensive observability stack:

- **Prometheus**: For metrics collection and storage
- **Grafana**: For visualization and dashboards
- **Jaeger**: For distributed tracing
- **OpenTelemetry Collector**: For telemetry collection and processing

The observability components are deployed using the `observability` module, which combines multiple tools for a complete monitoring solution.

## Disaster Recovery

The infrastructure includes backup and recovery mechanisms:

- **State Management**: Terraform state is stored in MinIO (S3-compatible storage)
- **Configuration Backups**: Infrastructure configurations are version-controlled in Git
- **Database Backups**: Persistent volumes for databases are backed up

## Security

Security is a core consideration in the infrastructure design:

- **Vault Integration**: Secrets are managed in HashiCorp Vault
- **TLS Everywhere**: All services use TLS certificates managed by cert-manager
- **Network Policies**: Traffic between services is controlled via Kubernetes network policies
- **CI/CD Security**: GitHub Actions and GitLab CI workflows include security scanning

## Usage

### Prerequisites

- Terraform v1.10.5 or higher
- kubectl configured for your clusters
- Vault token for accessing secrets

### Terraform Workflow

```bash
# Initialize Terraform
terraform init

# Select workspace (dev, stg, prod, sandbox, runners, tools)
terraform workspace select dev

# Plan changes
terraform plan -out=plan.tfplan

# Apply changes
terraform apply plan.tfplan
```

### GitHub Actions Workflows

The repository includes several GitHub Actions workflows for automation:

- **terraform-plan.yml**: Runs `terraform plan` on pull requests
- **terraform-apply.yml**: Applies Terraform changes when pull requests are merged
- **ansible.yml**: Runs Ansible playbooks for VM configuration
- **sec-trivy.yml**: Scans infrastructure code for security issues
- **sec-trufflehog.yml**: Scans for sensitive information in the repository

## Contributing

When contributing to this repository, please follow these guidelines:

1. **Module Structure**: Follow the established module structure and composition pattern
2. **Resource Tracking**: Always include `moved` blocks when refactoring resources
3. **Testing**: Test changes in a non-production environment before applying to production
4. **Documentation**: Update documentation to reflect any infrastructure changes

## Diagram

Below is an old dated homelab architecture diagram, I'll build a better one soon:

![image](fullstack.drawio.svg)