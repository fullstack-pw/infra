# Infrastructure as Code (IaC) Practices

## Overview

This document showcases the comprehensive Infrastructure as Code (IaC) practices implemented across the fullstack.pw organization repositories. The homelab demonstrates enterprise-grade IaC patterns, tools, and methodologies applied to a sophisticated multi-cluster Kubernetes environment running on self-hosted infrastructure.

## Table of Contents

- [IaC Tools & Technologies](#iac-tools--technologies)
- [Repository Architecture](#repository-architecture)
- [Core IaC Practices](#core-iac-practices)
  - [1. Terraform Infrastructure Management](#1-terraform-infrastructure-management)
  - [2. Kubernetes Manifests](#2-kubernetes-manifests)
  - [3. Helm Charts](#3-helm-charts)
  - [4. Kustomize Configuration Management](#4-kustomize-configuration-management)
  - [5. ArgoCD GitOps](#5-argocd-gitops)
  - [6. Ansible Automation](#6-ansible-automation)
  - [7. Container Infrastructure](#7-container-infrastructure)
  - [8. CI/CD Pipeline-as-Code](#8-cicd-pipeline-as-code)
  - [9. Secret Management](#9-secret-management)
  - [10. KubeVirt Virtual Machines](#10-kubevirt-virtual-machines)
- [Infrastructure Managed](#infrastructure-managed)
- [Best Practices Summary](#best-practices-summary)

---

## IaC Tools & Technologies

| Tool | Purpose | Repositories |
|------|---------|--------------|
| **Terraform** | Infrastructure provisioning & management | infra |
| **Kubernetes** | Container orchestration | All repositories |
| **Helm** | Kubernetes package management | infra |
| **Kustomize** | Kubernetes configuration management | demo-apps, cks-backend, cks-frontend |
| **ArgoCD** | GitOps continuous delivery | infra, demo-apps |
| **Ansible** | VM configuration automation | infra |
| **Docker** | Container packaging | All repositories |
| **GitHub Actions** | CI/CD automation | All repositories |
| **GitLab CI** | Alternative CI/CD platform | infra, pipelines |
| **SOPS + age** | Secret encryption | infra |
| **HashiCorp Vault** | Secret management | infra |
| **KubeVirt** | VM orchestration on Kubernetes | infra, cks-backend |
| **Istio** | Service mesh | infra, demo-apps, cks-backend, cks-frontend |
| **cert-manager** | TLS certificate automation | infra, demo-apps, cks-backend, cks-frontend |
| **Cloud-init** | VM bootstrapping | infra, cks-backend |

---

## Repository Architecture

```
fullstack.pw/
├── infra/                    # Core infrastructure definitions
│   ├── clusters/            # Terraform cluster configurations
│   ├── modules/             # Reusable Terraform modules
│   ├── proxmox/             # VM definitions and Ansible playbooks
│   ├── argocd-apps/         # ArgoCD application definitions
│   └── secrets/             # SOPS-encrypted secrets
│
├── demo-apps/               # Microservices demo application
│   └── apps/
│       ├── memorizer/       # Image processing service
│       ├── writer/          # Data persistence service
│       ├── enqueuer/        # Message queue service
│       ├── ascii-frontend/  # React frontend
│       └── realstate-scrapper/ # Web scraping service
│
├── cks-backend/             # CKS training platform backend
│   ├── kustomize/           # K8s manifests
│   ├── src/templates/       # KubeVirt VM templates
│   └── src/scenarios/       # Training scenarios
│
├── cks-frontend/            # CKS training platform frontend
│   └── kustomize/           # K8s manifests with overlays
│
└── pipelines/               # Centralized CI/CD templates
    ├── .github/workflows/   # Reusable GitHub Actions
    └── ci-templates.yml     # GitLab CI templates
```

---

## Core IaC Practices

### 1. Terraform Infrastructure Management

**Repository:** [infra](https://github.com/fullstack-pw/infra)

**Location:** `/clusters/`, `/modules/`, `/proxmox/`

#### Key Features

##### State Management
- **Backend:** S3-compatible (MinIO) at `https://s3.fullstack.pw`
- **Workspaces:** Environment isolation (dev, stg, prod, tools, observability, home, sandboxy)
- **State locking:** Enabled via S3 backend

##### Module Architecture

**Two-tier module system:**

1. **Base Modules** (`modules/base/`):
   - `helm`: Standardized Helm chart deployment
   - `namespace`: Kubernetes namespace with labels
   - `values-template`: Dynamic Helm values rendering
   - `istio-gateway`: Istio Gateway resources
   - `istio-virtualservice`: Istio routing
   - `persistence`: Volume management
   - `credentials`: Secret handling
   - `monitoring`: Prometheus ServiceMonitor

2. **Application Modules** (`modules/apps/`):
   - `argocd`: GitOps platform
   - `certmanager`: TLS automation
   - `externaldns`: DNS synchronization (PiHole & Cloudflare)
   - `external-secrets`: Vault integration
   - `github-runner`: GitHub Actions self-hosted runners
   - `gitlab-runner`: GitLab CI runners
   - `harbor`: Container registry
   - `ingress-nginx`: Ingress controller
   - `istio`: Service mesh
   - `kubevirt`: VM orchestration
   - `longhorn`: Distributed storage
   - `minio`: S3-compatible storage
   - `observability`: Full monitoring stack (Prometheus, Grafana, Jaeger, Loki, OpenTelemetry)
   - `postgres`: PostgreSQL with pgvector
   - `vault`: Secret management

##### VM Infrastructure as Code

**YAML-based VM definitions** (`proxmox/vms/*.yaml`):
```yaml
name: k8s-dev
target_node: node03
cores: 4
memory: 4096
nested_disks:
  scsi: ...
ipconfig0: "ip=192.168.1.12/24,gw=192.168.1.1"
```

**Terraform integration:**
- Dynamic VM creation from YAML files via `for_each`
- Cloud-init integration
- Lifecycle management

##### Best Practices
- Modular composition (base modules → app modules)
- Workspace-based isolation
- Remote state with S3 backend
- Dynamic resource creation
- SOPS integration for sensitive data
- Provider version pinning
- Template rendering for configuration

**Example:** [infra/modules/base/helm](https://github.com/fullstack-pw/infra/tree/main/modules/base/helm)

---

### 2. Kubernetes Manifests

**Repositories:** All application repositories

**Pattern:** Native YAML manifests for Kubernetes resources

#### Common Resources

##### Deployments
**Features:**
- Resource requests and limits defined
- Readiness and liveness probes
- Security contexts (non-root, fsGroup)
- Environment-specific configurations
- Health check endpoints

**Example:** [demo-apps/apps/memorizer/kustomize/base/deployment.yaml](https://github.com/fullstack-pw/demo-apps)
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

##### Services
- ClusterIP for internal services
- Port mappings
- Label selectors

##### ConfigMaps
- Application configuration
- Environment variables
- Feature flags

##### Secrets
- Integration with `external-secrets` operator
- Vault-backed secrets
- SOPS-encrypted at rest in Git

#### Best Practices
- Resource limits prevent resource exhaustion
- Health probes enable zero-downtime deployments
- ConfigMaps externalize configuration
- Non-root security contexts
- Namespace isolation

---

### 3. Helm Charts

**Repository:** [infra](https://github.com/fullstack-pw/infra)

**Location:** `modules/base/helm/`, `modules/apps/*/`

#### Standardized Helm Module

**Base wrapper** (`modules/base/helm/main.tf`) provides:
- Repository management
- Version pinning
- Dynamic value injection
- Namespace creation control
- Timeout configuration
- Atomic deployments with rollback

#### Charts Deployed

| Chart | Version | Purpose |
|-------|---------|---------|
| ArgoCD | 7.7.12 | GitOps platform |
| kube-prometheus-stack | Latest | Monitoring |
| Loki | Latest | Log aggregation |
| Jaeger Operator | Latest | Distributed tracing |
| Istio | Latest | Service mesh |
| cert-manager | Latest | Certificate automation |
| Harbor | Latest | Container registry |
| Longhorn | Latest | Persistent storage |
| Actions Runner Controller | Latest | GitHub Actions runners |

#### Best Practices
- Centralized release management
- Values templating for environments
- Sensitive value handling via `set_sensitive`
- Repository and version explicit declaration
- Atomic deployments with rollback capability

**Example:** [infra/modules/apps/argocd](https://github.com/fullstack-pw/infra/tree/main/modules/apps/argocd)

---

### 4. Kustomize Configuration Management

**Repositories:** demo-apps, cks-backend, cks-frontend

**Pattern:** Base + Overlay architecture

#### Structure Pattern
```
kustomize/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── virtualservice.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── configmap
    ├── stg/
    │   ├── kustomization.yaml
    │   └── configmap
    └── prod/
        ├── kustomization.yaml
        ├── configmap
        └── replicas.yaml
```

#### Base Configuration
- Reusable resource definitions
- Placeholder values for environment-specific data
- Common labels and annotations

#### Environment Overlays

**Development:**
- LOG_LEVEL=DEBUG
- Single replica
- Dev hostnames (dev.*.fullstack.pw)
- Relaxed resource limits

**Staging:**
- LOG_LEVEL=DEBUG
- Single replica
- Staging hostnames (stg.*.fullstack.pw)
- Production-like configuration

**Production:**
- LOG_LEVEL=INFO
- Multiple replicas (HA)
- Production hostnames (*.fullstack.pw)
- Strict resource limits
- JSON patches for scaling

#### Patch Strategies

**JSON Patches (RFC 6902):**
```yaml
patches:
  - target:
      kind: Deployment
      name: cks-frontend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
```

**ConfigMap Generator:**
```yaml
configMapGenerator:
  - name: app-config
    behavior: merge
    envs:
      - configmap
```

#### Best Practices
- DRY principle - base reused across environments
- Environment-specific customizations
- No configuration duplication
- Easy to add new environments
- Clear separation of concerns

**Example:** [demo-apps/apps/memorizer/kustomize](https://github.com/fullstack-pw/demo-apps)

---

### 5. ArgoCD GitOps

**Repository:** [infra](https://github.com/fullstack-pw/infra)

**Location:** `argocd-apps/`

#### App-of-Apps Pattern

**Parent Application** (`argocd-apps/app-of-apps/dev-apps.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dev-apps
spec:
  source:
    repoURL: https://github.com/fullstack-pw/infra.git
    targetRevision: main
    path: argocd-apps/app-of-apps/dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Child Applications:**
- `writer.yaml`: Writer service
- `enqueuer.yaml`: Enqueuer service
- `memorizer.yaml`: Memorizer service

#### Sync Waves and Hooks

**Demo:** `argocd-apps/sync-waves-demo.yaml`

**Features:**
- **PreSync hooks:** Run before synchronization
- **PostSync hooks:** Run after successful sync
- **Sync waves:** Ordered deployment (-1, 0, 1)
- **Hook deletion policies:** BeforeHookCreation

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

#### Best Practices
- Declarative GitOps approach
- Automated sync with self-healing
- Resource pruning for drift prevention
- Multi-environment support
- Ordered deployments via sync waves
- Lifecycle hooks for complex deployments

**Example:** [infra/argocd-apps](https://github.com/fullstack-pw/infra/tree/main/argocd-apps)

---

### 6. Ansible Automation

**Repository:** [infra](https://github.com/fullstack-pw/infra)

**Location:** `proxmox/playbooks/`

#### Playbooks

| Playbook | Purpose |
|----------|---------|
| `k8s.yml` | K3s single-node cluster installation |
| `k8s-tools.yml` | Tools cluster setup |
| `k8s-vanilla-bootstrap.yml` | Vanilla Kubernetes bootstrapping |
| `longhorn-prep.yml` | Longhorn storage preparation |
| `haproxy-config.yml` | HAProxy load balancer |
| `teleport.yml` | Teleport agent deployment |
| `cluster-api.yml` | Cluster API setup |

#### K3s Installation Features

**Playbook:** `proxmox/playbooks/k8s.yml`

```yaml
- name: Install K3s
  shell: |
    curl -sfL https://get.k3s.io | sh -s - \
      --disable traefik \
      --disable servicelb \
      --default-local-storage-path /mnt/storage
```

**Capabilities:**
- K3s installation with custom configuration
- Local-path storage setup
- Kubeconfig extraction
- Vault integration for kubeconfig storage
- Service management and validation

#### Integration Points
- **Vault API:** Secret storage integration
- **Python scripts:** Kubeconfig management
- **Cloud-init:** SSH key injection
- **Inventory-based targeting**

#### Best Practices
- Idempotent task design
- Error handling (failed_when, ignore_errors)
- Fact-based conditional logic
- Delegate-to-localhost for control plane ops
- Dynamic hostname resolution

**Example:** [infra/proxmox/playbooks/k8s.yml](https://github.com/fullstack-pw/infra/tree/main/proxmox/playbooks)

---

### 7. Container Infrastructure

**Repositories:** All application repositories

#### Multi-Stage Docker Builds

##### Go Applications
**Pattern:** Builder + minimal runtime

```dockerfile
# Builder stage
FROM golang:1.23.1-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app

# Runtime stage
FROM alpine:3.19
COPY --from=builder /app/app /app
USER 1001:1001
CMD ["/app"]
```

**Applications:**
- memorizer, writer, enqueuer (demo-apps)
- cks-backend
- realstate-scrapper

##### Node.js Applications
**Pattern:** Build + nginx static serving

```dockerfile
# Builder stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime stage
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
```

**Applications:**
- ascii-frontend (demo-apps)
- cks-frontend

##### Specialized Images

**PostgreSQL with pgvector** ([infra/modules/apps/postgres/Dockerfile](https://github.com/fullstack-pw/infra)):
```dockerfile
FROM tensorchord/pgvecto-rs-binary:pg15-v0.3.0 AS pgvector
FROM bitnami/postgresql:15.10.0
COPY --from=pgvector /pgvecto-rs-binary-release.deb /tmp/
RUN apt-get update && apt-get install -y /tmp/pgvecto-rs-binary-release.deb
```

**GitHub Actions Runner** ([infra/modules/apps/github-runner/Dockerfile](https://github.com/fullstack-pw/infra)):
- Base: Official GitHub Actions runner
- Tools: kubectl, Helm, Terraform, SOPS, Docker CLI
- Purpose: Self-hosted CI/CD with full IaC toolchain

#### Best Practices
- Multi-stage builds for minimal size
- Layer caching optimization
- Non-root user execution
- Version pinning for reproducibility
- Security-first approach
- Health check endpoints

---

### 8. CI/CD Pipeline-as-Code

**Repositories:** All repositories, centralized in [pipelines](https://github.com/fullstack-pw/pipelines)

#### GitHub Actions - Reusable Workflows

**Repository:** pipelines

**Reusable Workflows:**

##### Build and Push
**File:** `.github/workflows/build-and-push.yml`

```yaml
name: Build and Push Docker Image
on:
  workflow_call:
    inputs:
      app-context:
        required: true
        type: string
      app-name:
        required: true
        type: string
```

**Features:**
- Docker BuildKit support
- Harbor registry integration
- Multi-tag strategy (SHA + latest)
- Self-hosted runners

##### Deploy Kustomize
**File:** `.github/workflows/deploy-kustomize.yml`

```yaml
name: Deploy with Kustomize
on:
  workflow_call:
    inputs:
      kustomize-dir:
        required: true
        type: string
      context:
        required: true
        type: string
```

**Features:**
- Dynamic manifest generation
- Image tag substitution (latest → SHA)
- Multi-cluster support
- Deployment verification (rollout status)

##### IaC Security Tests
**File:** `.github/workflows/iac-tests.yml`

```yaml
name: IaC Security Testing
on:
  workflow_call:
    inputs:
      iac-directory:
        required: true
        type: string
```

**Features:**
- Trivy security scanner
- SARIF output for GitHub Security
- Critical/High severity focus
- CI/CD security gates

##### Go Tests
**File:** `.github/workflows/go-tests.yml`

**Features:**
- Unit testing
- golangci-lint integration
- Conditional Go installation

##### Cypress E2E Tests
**File:** `.github/workflows/cypress.yml`

**Features:**
- Container-based execution
- Dynamic environment variables
- Integration testing

#### GitLab CI Templates

**Repository:** pipelines

**File:** `ci-templates.yml`

**Templates:**
- `.go_tests`: Go testing
- `.build-docker-image-template`: Docker builds with DinD
- `.deploy-app-template`: Kustomize deployments
- `.cypress-template`: E2E testing

#### Application CI/CD Pipelines

##### infra Repository
**Workflows:**
- `terraform-plan.yml`: PR validation with parallel plans
- `terraform-apply.yml`: Infrastructure changes on merge
- `build.yml`: Dockerfile change detection and builds
- `sec-trivy.yml`: Container security scanning
- `sec-trufflehog.yml`: Secret scanning
- `conventional-commits.yml`: Commit validation
- `release.yml`: Semantic release automation

**GitLab CI:** `.gitlab-ci.yml`
- Stages: validate → plan → apply
- SOPS + age setup
- Vault token injection
- Artifact management
- Manual apply gates

##### Application Repositories
**Common pipeline pattern:**
1. **docker-build-and-push:** Build container
2. **dev-deploy:** Deploy to development
3. **dev-tests:** Run E2E tests
4. **stg-deploy:** Deploy to staging (conditional)
5. **stg-tests:** Run E2E tests
6. **prod-deploy:** Deploy to production (conditional/manual)
7. **versioning:** Semantic release

**Example:** [demo-apps/.github/workflows/pipeline.yml](https://github.com/fullstack-pw/demo-apps)

#### Best Practices
- Reusable workflows prevent duplication
- Security scanning integration
- Multi-environment progression
- Test gates between environments
- Automated versioning
- Self-hosted runner infrastructure
- GitOps-style deployments
- Artifact preservation

---

### 9. Secret Management

**Repository:** [infra](https://github.com/fullstack-pw/infra)

**Technologies:** SOPS, age, HashiCorp Vault, External Secrets Operator

#### SOPS Configuration

**File:** `.sops.yaml`
```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea9zxpx3eagyqfqlsgdytsp
```

#### Secret Files

**Location:** `secrets/common/`
- `cloudflare.yaml`: Cloudflare API tokens
- `cluster-secrets.yaml`: Cluster-wide secrets
- `github-runner.yaml`: GitHub PAT for runners
- `gitlab-runner.yaml`: GitLab runner tokens
- `cluster-secret-store/`: External Secrets data

#### Secret Loading Process

**Script:** `clusters/load_secrets.py`
```python
# Decrypts SOPS-encrypted YAML
# Transforms to JSON for Terraform
# Environment-aware loading
# Vault integration
```

#### Integration Flow

```
1. Git Repository (SOPS encrypted)
         ↓
2. CI/CD Pipeline (decrypts)
         ↓
3. Terraform (consumes JSON)
         ↓
4. HashiCorp Vault (stores)
         ↓
5. External Secrets Operator (syncs)
         ↓
6. Kubernetes Secrets (consumed by apps)
```

#### Best Practices
- Encryption at rest in Git (SOPS)
- Decryption only in CI/CD
- Vault as runtime secret store
- External Secrets Operator for K8s integration
- No secrets in container images
- Age-based asymmetric encryption

**Example:** [infra/secrets](https://github.com/fullstack-pw/infra/tree/main/secrets)

---

### 10. KubeVirt Virtual Machines

**Repositories:** [infra](https://github.com/fullstack-pw/infra), [cks-backend](https://github.com/fullstack-pw/cks-backend)

#### VM Templates as Code

**Location:** cks-backend/src/templates/

##### Control Plane Template
**File:** `control-plane-template.yaml`

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: {{.ClusterName}}-control-plane
  labels:
    session: {{.SessionID}}
    role: control-plane
spec:
  template:
    spec:
      domain:
        cpu:
          cores: {{.CPUCores}}
        memory:
          guest: {{.Memory}}Mi
        devices:
          disks:
            - name: system
              disk:
                bus: virtio
          interfaces:
            - name: default
              bridge: {}
      volumes:
        - name: system
          dataVolume:
            name: {{.ClusterName}}-control-plane-disk
---
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: {{.ClusterName}}-control-plane-disk
spec:
  source:
    pvc:
      namespace: {{.GoldenImageNamespace}}
      name: {{.GoldenImageName}}
  pvc:
    storageClassName: {{.StorageClass}}
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: {{.DiskSize}}Gi
```

##### Cloud-init Configuration
**File:** `control-plane-cloud-config.yaml`

```yaml
#cloud-config
runcmd:
  - |
    # Initialize Kubernetes control plane
    kubeadm init \
      --pod-network-cidr={{.PodCIDR}} \
      --apiserver-advertise-address={{.ControlPlaneIP}}

    # Install CNI (Cilium)
    kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.17.3/install/kubernetes/quick-install.yaml

    # Generate join command for workers
    kubeadm token create --print-join-command > /tmp/join-command
```

#### Infrastructure Managed
- Dynamic Kubernetes cluster provisioning
- Multi-node clusters (control-plane + workers)
- Session-based resource isolation
- Golden image cloning
- Automated cluster bootstrapping

#### Best Practices
- Template-based VM creation
- Variable substitution for flexibility
- Golden image pattern for consistency
- Cloud-init for automation
- Resource labeling for tracking
- Idempotent configuration scripts

**Example:** [cks-backend/src/templates](https://github.com/fullstack-pw/cks-backend/tree/main/src/templates)

---

## Infrastructure Managed

### Physical Infrastructure
- **3 Physical Hosts:**
  - Acer Nitro
  - HP Mini PC
  - X99 dual-Xeon server
- **Hypervisor:** Proxmox VE

### Kubernetes Clusters
- **7 Clusters:** dev, stg, prod, tools, home, sandboxy, observability
- **Distribution:** K3s (lightweight) and vanilla Kubernetes
- **Nodes:** Multiple VMs across physical hosts

### Network Services
- **DNS:** PiHole + External-DNS
- **Load Balancing:** HAProxy, MetalLB
- **CDN/Security:** Cloudflare
- **Service Mesh:** Istio

### Storage Solutions
- **Distributed:** Longhorn
- **Object Storage:** MinIO (S3-compatible)
- **Local:** local-path provisioner

### Platform Services
- **GitOps:** ArgoCD
- **Container Registry:** Harbor
- **Secret Management:** HashiCorp Vault
- **Monitoring:** Prometheus, Grafana, Jaeger, Loki
- **Tracing:** OpenTelemetry
- **Certificate Management:** cert-manager + Let's Encrypt

### Application Portfolio
- **Demo Microservices:** 5 services (memorizer, writer, enqueuer, ascii-frontend, realstate-scrapper)
- **CKS Training Platform:** Frontend + Backend
- **CI/CD Infrastructure:** GitHub Actions runners, GitLab runners

---

## Best Practices Summary

### General IaC Principles
- **Everything as Code:** All infrastructure defined in version-controlled files
- **Declarative Configuration:** Desired state vs imperative commands
- **Immutable Infrastructure:** Replace rather than modify
- **Version Control:** Git as single source of truth
- **Code Review:** All changes via pull requests
- **Automated Testing:** Security scanning, validation, E2E tests

### Modularity & Reusability
- **Terraform Modules:** Two-tier architecture (base + apps)
- **Kustomize Base/Overlays:** DRY principle for K8s configs
- **Reusable Workflows:** Centralized CI/CD templates
- **Docker Multi-Stage:** Optimized, reusable build patterns

### Security
- **Secret Encryption:** SOPS + age for secrets at rest
- **Secret Management:** Vault for runtime secrets
- **Security Scanning:** Trivy, Trufflehog integration
- **Non-Root Containers:** All containers run as non-root users
- **Network Policies:** Service mesh for secure communication
- **Certificate Automation:** cert-manager for TLS

### Multi-Environment Management
- **Workspace Isolation:** Terraform workspaces per environment
- **Overlay Pattern:** Kustomize overlays for dev/stg/prod
- **Environment Promotion:** CI/CD pipeline progression
- **Configuration Management:** Environment-specific configs

### GitOps & Automation
- **ArgoCD:** Declarative, Git-driven deployments
- **Automated Sync:** Self-healing and drift prevention
- **CI/CD Integration:** Automated builds, tests, deployments
- **Semantic Versioning:** Automated releases

### Observability
- **Metrics:** Prometheus monitoring
- **Logging:** Loki log aggregation
- **Tracing:** Jaeger distributed tracing
- **OpenTelemetry:** Standardized telemetry
- **Health Checks:** Readiness and liveness probes

### Scalability & Reliability
- **Resource Limits:** CPU and memory constraints
- **High Availability:** Multi-replica deployments in prod
- **Rolling Updates:** Zero-downtime deployments
- **Distributed Storage:** Longhorn for data persistence
- **Service Mesh:** Istio for resilience patterns

### Developer Experience
- **Makefile Automation:** Common operations simplified
- **Local Development:** Docker Compose, local clusters
- **Documentation:** Comprehensive README files
- **Self-Service:** Makefile commands for infra operations

---

## Key Metrics

- **Repositories:** 5 (infra, demo-apps, cks-backend, cks-frontend, pipelines)
- **IaC Tools:** 14+ different technologies
- **Terraform Modules:** 30+ (base + application modules)
- **Kubernetes Clusters:** 7 environments
- **Physical Hosts:** 3 servers
- **Container Images:** 10+ custom images
- **CI/CD Pipelines:** 20+ workflow definitions
- **Applications Deployed:** 20+ services
- **Lines of IaC:** 10,000+ lines (Terraform, K8s manifests, CI/CD configs)

---

## Conclusion

The fullstack.pw homelab demonstrates enterprise-grade Infrastructure as Code practices across the entire technology stack. From bare-metal Proxmox VMs to Kubernetes clusters, from container builds to application deployments, every component is defined as code, version-controlled, and automated.

This comprehensive IaC approach enables:
- **Rapid Environment Provisioning:** Spin up entire environments in minutes
- **Consistency:** Infrastructure parity across dev/stg/prod
- **Disaster Recovery:** Full infrastructure reproducible from Git
- **Collaboration:** Team-friendly with code review processes
- **Learning:** Educational showcase of modern DevOps practices

The repository collection serves as a reference architecture for building production-ready infrastructure using open-source tools and GitOps methodologies.

---

## Related Documentation

- [CI/CD Documentation](./CICD.md)
- [Istio Migration Guide](./ISTIO_MIGRATION.md)
- [Infrastructure Repository README](../README.md)

---

**Last Updated:** 2025-11-05
**Maintained by:** fullstack.pw organization
