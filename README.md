# fullstack.pw Infrastructure

This repository contains the infrastructure-as-code for the **fullstack.pw** homelab environment. It manages multiple Kubernetes clusters (K3s and vanilla), Proxmox VMs, and supporting services through a modular, declarative approach.

## Overview

The environment is designed as a production-grade homelab platform for:

- **Multi-environment Deployments**: Managing dev, staging, production, and tooling environments
- **Infrastructure Automation**: Provision and configure infrastructure using Terraform and Ansible
- **Observability**: Comprehensive monitoring with Prometheus, Grafana, Jaeger, and OpenTelemetry
- **CI/CD Integration**: Self-hosted runners for GitHub Actions and GitLab CI
- **Security**: Vault for secrets management, cert-manager for TLS, and External Secrets for Kubernetes integration

## Repository Structure

```
infra/
├── .github/workflows/    # GitHub Actions workflows for CI/CD
├── clusters/             # Kubernetes cluster configurations
├── modules/              # Reusable Terraform modules
│   ├── base/             # Base modules (building blocks)
│   └── apps/             # Application modules
├── proxmox/              # Proxmox VM configurations
│   ├── vms/              # YAML VM definitions
│   ├── playbooks/        # Ansible playbooks
│   └── scripts/          # Helper scripts
└── secrets/              # Encrypted secrets (SOPS)
```

## Key Components

### Infrastructure Layer

- **Proxmox Management**: Provisions VMs from YAML definitions
- **PXE Boot Server**: Network boot for quick node provisioning
- **K3s Clusters**: Lightweight Kubernetes clusters for dev, staging, and production
- **Vanilla K8s**: Multi-node Kubernetes cluster for sandbox environments

### Platform Services

- **Certificate Management**: Automatic TLS using cert-manager and Let's Encrypt
- **DNS Management**: ExternalDNS integration for automatic DNS record updates
- **Secret Management**: HashiCorp Vault with Kubernetes integration via External Secrets
- **Storage**: MinIO S3-compatible object storage
- **Container Registry**: Private Docker registry
- **Ingress**: NGINX ingress controllers with custom configurations

### Observability Stack

- **Metrics**: Prometheus for infrastructure and application metrics
- **Dashboards**: Grafana for visualization
- **Tracing**: Jaeger and OpenTelemetry for distributed tracing
- **Logging**: Fluent Bit for log collection and forwarding to Loki

### CI/CD Integration

- **GitHub Actions Runners**: Self-hosted via actions-runner-controller
- **GitLab Runners**: Self-hosted GitLab CI executor
- **Shared Pipelines**: Reusable workflow templates for application deployments

## Getting Started

### Prerequisites

- Terraform v1.10.5+
- kubectl
- Ansible
- SOPS for secret management
- Access to Proxmox and Vault

### Provisioning Infrastructure

1. **Initialize Terraform**

```bash
terraform init
```

2. **Configure Variables**

Create a `terraform.tfvars` file with required variables (see `terraform.tfvars.example`).

3. **Plan and Apply**

```bash
# For Proxmox VMs
cd proxmox
terraform plan -out=plan.tfplan
terraform apply plan.tfplan

# For Kubernetes resources
cd clusters
terraform workspace select dev  # or stg, prod, sandbox, tools
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

### Configure VMs with Ansible

```bash
# Run playbook for specific environment
cd proxmox
ansible-playbook playbooks/k8s.yml -i k8s.ini -e "target_hosts=dev"
```

## Workflows

The repository includes several GitHub Actions workflows:

- **terraform-plan.yml**: Runs `terraform plan` on pull requests
- **terraform-apply.yml**: Applies changes when PRs are merged
- **ansible.yml**: Runs Ansible playbooks for VM configuration
- **sec-trivy.yml**: Security scanning with Trivy
- **iac-tests.yml**: Infrastructure as Code testing

## Module Design

The infrastructure follows these principles:

1. **Composability**: Base modules can be combined to create more complex app modules
2. **Standardization**: Common patterns implemented consistently
3. **DRY (Don't Repeat Yourself)**: Reusable configurations
4. **Separation of Concerns**: Each module has a single responsibility

### Base Modules

- **namespace**: Kubernetes namespace management
- **helm**: Standardized Helm chart deployment
- **values-template**: Template rendering for Helm values
- **ingress**: Common ingress configuration
- **persistence**: Volume management
- **credentials**: Secret handling
- **monitoring**: Prometheus integration

### Application Modules

Built from base modules to provide complete solutions:

- **cert-manager**: TLS certificate automation
- **externaldns**: DNS record management
- **external-secrets**: External secret integration
- **fluent**: Log collection and forwarding
- **github-runner**: GitHub Actions runners
- **gitlab-runner**: GitLab CI runners
- **ingress-nginx**: Ingress controller
- **minio**: S3-compatible storage
- **nats**: Messaging system
- **observability**: Complete monitoring stack
- **otel-collector**: OpenTelemetry collector
- **postgres**: PostgreSQL database
- **redis**: Redis database/cache
- **registry**: Docker registry
- **vault**: Secret management

## Physical Infrastructure

The homelab runs on:

- **NODE01**: Acer Nitro (i7-4710HQ, 16GB RAM)
- **NODE02**: HP ED800 G3 Mini (i7-7700T, 32GB RAM)
- **Lenovo Legion**: For ephemeral CI/CD runners

## Network Architecture

- **Cloudflare**: DNS, CDN, and WAF for public-facing services
- **HAProxy**: Load balancer for Kubernetes traffic
- **Internal DNS**: Local name resolution
- **MetalLB**: Kubernetes load balancing

## Security

- **Vault**: Centralized secret management
- **External Secrets**: Kubernetes secret integration
- **cert-manager**: Automated TLS certificate management
- **SOPS**: Secret encryption in Git
- **Trivy**: Security scanning
