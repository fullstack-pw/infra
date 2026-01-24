# fullstack.pw Infrastructure

Production-grade infrastructure-as-code repository demonstrating enterprise DevOps practices, GitOps workflows, and cloud-native architectures implemented in a homelab environment.

## DevOps Practices

### Infrastructure as Code

**OpenTofu-Driven Infrastructure**
- Modular two-tier architecture: base modules and application modules promoting composability and reusability
- S3-compatible remote state backend ([s3.fullstack.pw](https://s3.fullstack.pw)) with workspace isolation per environment
- Automated state backup to Oracle Cloud Object Storage via CronJob for disaster recovery
- YAML-driven VM provisioning using dynamic `for_each` loops for declarative infrastructure definitions

**Configuration Management**
- Ansible playbooks for VM configuration (K3s, vanilla Kubernetes, HAProxy, Talos Linux)
- Dynamic inventory auto-generated from Terraform outputs and automatically committed to Git
- Integration with HashiCorp Vault for centralized kubeconfig and secrets management
- Idempotent playbook design for reliable repeated execution

### GitOps Methodology

**Git as Single Source of Truth**
- All infrastructure changes submitted via pull requests with automated validation
- Commit message parsing for workflow automation triggers
- ArgoCD implementation with app-of-apps pattern for hierarchical application management
- Sync waves and hooks for ordered, controlled deployments
- Self-healing enabled with automatic drift detection and remediation

**Automated CI/CD Pipelines**

10 GitHub Actions workflows provide comprehensive automation:

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| opentofu.yml | OpenTofu workflow, plans on PR and apply on merge | PR/Merge to main |
| ansible.yml | VM provisioning via `[ansible PLAYBOOK]` commit tag | Commit tag detection |
| build.yml | Docker image builds on Dockerfile changes | File path changes |
| sec-trivy.yml | Container and IaC vulnerability scanning | Pull request / Push |
| sec-trufflehog.yml | Secret leak detection in commits | Pull request / Push |
| conventional-commits.yml | Commit message validation | Pull request |
| release.yml | Semantic versioning and changelog generation | Merge to main |


**Progressive Delivery with Argo Rollouts**

Blue-Green deployment strategy with automated E2E testing and production promotion:

1. **Build Phase**: GitHub Actions builds and pushes container image to Harbor registry
2. **Dev Deployment**: Pipeline updates dev kustomization with new image tag, ArgoCD syncs
3. **E2E Testing**: Argo Rollouts triggers prePromotionAnalysis running Cypress tests against dev environment
4. **Auto-Promotion**: On test success, postPromotionAnalysis job automatically promotes to prod by updating prod kustomization
5. **Prod Deployment**: ArgoCD syncs prod overlay, Argo Rollouts performs Blue-Green switch

```
Build → Push Image → Update Dev Tag → ArgoCD Sync → Cypress Tests → Update Prod Tag → ArgoCD Sync → Live
```

Key components:
- AnalysisTemplate with Kubernetes Job provider for Cypress test execution
- Separate AnalysisTemplate per application for production promotion (git commit automation)
- `autoPromotionEnabled: true` for fully automated pipeline
- Prod overlay removes prePromotionAnalysis (tests only run in dev)

**Self-Hosted Runner Infrastructure**
- Actions Runner Controller (ARC) deployed on tools cluster
- Custom runner image with kubectl, Helm, Terraform, SOPS, Docker CLI, and cloud provider tools
- GitLab CI runners for multi-platform pipeline support
- Centralized reusable workflows in dedicated pipelines repository

### Continuous Observability

**Hub-and-Spoke Architecture**

Central observability hub on dedicated cluster:
- Prometheus (kube-prometheus-stack v79.0.1) for metrics aggregation
- Grafana for unified multi-cluster dashboards
- Jaeger v2.57.0 for distributed tracing
- Loki v6.28.0 for log aggregation
- OpenTelemetry Collector v0.33.0 for telemetry ingestion

Edge collectors on all workload clusters:
- Fluent Bit v0.48.9 for log forwarding
- Prometheus with remote write capability
- OpenTelemetry Collector for traces and metrics
- Automatic cluster labeling for multi-cluster aggregation

**Application Instrumentation**
- OpenTelemetry SDK integration in Go microservices
- Structured JSON logging with trace context correlation
- ServiceMonitor CRDs for automatic Prometheus scraping
- Custom dashboards for PostgreSQL, Redis, NATS with predefined alerting rules

## Cluster Bootstrapping

### Cluster-API

Bootstrap dynamic kubeadm/talos clusters directly via OpenTofu.

### Single-Commit Ansible Workflow (LEGACY)

The `[ansible PLAYBOOK]` pattern enables fully automated cluster provisioning:

```bash
git commit -m "feat(proxmox): add k8s-observability VM [ansible k8s-observability]"
```

**Automated Pipeline Chain**
1. Release workflow generates semantic version tag
2. Terraform creates VM from YAML definition in Proxmox
3. Terraform updates Ansible inventory, preserving `[ansible]` tag in commit message
4. Ansible workflow triggers on tag detection
5. Ansible installs K3s/K8s, configures storage paths
6. Python script extracts kubeconfig, updates IP and context name
7. Kubeconfig merged into central Vault KV store
8. Cluster immediately available to Terraform and CI/CD pipelines

### Supported Kubernetes Distributions

| Distribution | Provisioning Method | Use Case |
|--------------|---------------------|----------|
| K3s | Ansible playbook with custom storage paths | Lightweight single-node clusters (dev, stg, prod, tools, home) |
| Vanilla K8s | Kubeadm via Ansible | Multi-node HA clusters (sandbox) |
| Talos Linux | Cluster API + Talos configs | Immutable infrastructure with declarative configuration |
| KubeVirt | Operator on existing K8s | Nested virtualization on Kubernetes (sandboxy) |

### Bootstrap Components

Terraform automatically deploys platform services to new clusters:
- cert-manager for TLS automation
- External-DNS for dynamic DNS record management
- External Secrets for Vault integration
- Observability stack (hub or edge collector based on cluster role)
- Ingress controllers (Istio or NGINX)
- ArgoCD for GitOps application delivery

## Infrastructure Resilience

### Disaster Recovery

**Automated Backup Strategy**
- Terraform state backed up daily to Oracle Cloud Object Storage via CronJob

**Recovery Capabilities**
- Complete infrastructure reproducible from Git repository alone
- Terraform state restoration from Oracle Cloud backups

### High Availability

**Multi-Cluster Architecture**
- 6 environment-isolated Kubernetes clusters (dev, prod, tools, home, sandboxy, observability)
- Production workloads distributed across multiple replicas via Kustomize overlays
- HAProxy load balancer for vanilla Kubernetes traffic distribution
- MetalLB for LoadBalancer service type support on bare metal

**Resource Management**
- Resource limits and requests prevent resource exhaustion
- Namespace quotas for multi-tenant isolation
- Anti-affinity rules for pod distribution (where configured)

## Security Implementation

### Secrets Management

**Multi-Layered Defense**

1. **Encryption at Rest**: SOPS with age encryption for all secrets in Git
   - Age public key: `age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea9zxpx3eagyqfqlsgdytsp`
   - Automated scripts: `secret_new.sh`, `secret_edit.sh`, `secret_view.sh`

2. **Runtime Secret Storage**: HashiCorp Vault deployed on tools cluster
   - KV v2 engine for versioned secrets
   - Kubernetes authentication backend
   - Dynamic policy creation via Terraform
   - Accessible at [vault.fullstack.pw](https://vault.fullstack.pw)

3. **Kubernetes Integration**: External Secrets Operator
   - ClusterSecretStore for multi-namespace secret distribution
   - Automatic synchronization from Vault to Kubernetes secrets
   - Support for secret rotation with namespace selector `cluster-secrets=true`

**Secret Lifecycle**
```
Git (SOPS encrypted) → CI/CD (decrypt) → Vault (runtime) → External Secrets → K8s Secrets → Pods
```

### Certificate Management

**Automated TLS**
- cert-manager with Let's Encrypt ClusterIssuer (`letsencrypt-prod`)
- Cloudflare DNS-01 challenge for wildcard certificate support
- Automatic renewal before expiration
- Istio Gateway integration for TLS termination
- Certificate validation monitoring
- Environment-specific gateway DNS names configured via OpenTofu variables:
  - Dev: `dev.app.fullstack.pw` pattern
  - Prod: `app.fullstack.pw` pattern (no prefix)

### Network Security

**Service Mesh Implementation**
- Istio deployed on dev cluster for traffic encryption and observability
- Mutual TLS (mTLS) capability between services
- VirtualServices for fine-grained routing control
- Gateway resources for ingress traffic management
- SNI-based routing for TLS passthrough (PostgreSQL example)

**DNS Security**
- External-DNS with TXT record ownership verification
- Cloudflare integration for public DNS with WAF protection
- Pi-hole for internal DNS with ad-blocking
- Automatic DNS record lifecycle management

### Access Control

**Kubernetes RBAC**
- ServiceAccounts with minimal permissions for all components
- ClusterRoles for platform services (External-DNS, External Secrets)
- Namespace-based isolation for tenant workloads
- Vault policies for least-privilege access

**CI/CD Security**
- Self-hosted runners in isolated network environment
- Secret injection only in authorized workflows
- No secrets embedded in container images
- Container scanning with Trivy before deployment

### Security Scanning

**Continuous Vulnerability Assessment**
- Trivy scanning for containers and IaC on every pull request
- TruffleHog secret leak detection in commit history
- SARIF output integration with GitHub Security tab
- Configurable blocking on critical vulnerabilities

**Secure Container Practices**
- Multi-stage Docker builds minimizing attack surface
- Non-root user execution enforced
- Minimal base images (Alpine, distroless)
- Regular base image updates via Renovate/Dependabot

## Repository Structure

```
infra/
├── clusters/             # Kubernetes workload definitions (Terraform)
├── modules/
│   ├── base/            # 11 foundational modules (helm, namespace, ingress, monitoring, etc.)
│   └── apps/            # 24 application modules (argocd, vault, observability, istio, etc.)
├── proxmox/
│   ├── vms/             # YAML VM definitions for declarative provisioning
│   ├── playbooks/       # Ansible configuration playbooks
│   └── scripts/         # Automation scripts (Talos, kubeconfig management)
├── argocd-apps/         # GitOps application manifests
├── secrets/             # SOPS-encrypted secrets
├── .github/workflows/   # CI/CD automation pipelines
└── docs/                # Technical documentation
```

## Physical Infrastructure

**Compute Resources**
- NODE01: Acer Nitro (i7-4710HQ, 16GB RAM)
- NODE02: HP ED800 G3 Mini (i7-7700T, 32GB RAM)
- NODE03: X99 dual Xeon E5-2699-V3 18-Core, 128GB RAM

**Virtualization**: Proxmox VE managing 10+ VMs across 3 physical hosts

## Kubernetes Environments

| Cluster | Type | Purpose | Node(s) | Key Workloads |
|---------|------|---------|---------|---------------|
| dev | Talos | Development environment | dynamic | Development services, Istio service mesh |
| prod | kubeadm | Production environment | dynamic | Production services |
| tools | K3s | Platform services | k8s-tools | cluster-api, PostgreSQL, Redis, NATS, CI/CD runners, Vault |
| home | K3s | Home automation | k8s-home | Immich photo management |
| observability | K3s | Central monitoring hub | k8s-observability | Prometheus, Grafana, Jaeger, Loki |
| sandboxy | K3s | Experimentation | k8s-sandbox | KubeVirt, Longhorn distributed storage |

## Technology Stack

**Infrastructure Layer**
- OpenTofu 1.11.3+, Ansible, Proxmox VE

**Kubernetes**
- K3s, kubeadm, Talos Linux

**Platform Services**
- ArgoCD 7.7.12, HashiCorp Vault, cert-manager, External Secrets Operator, Istio

**Observability**
- Prometheus (kube-prometheus-stack v79.0.1), Grafana, Jaeger v2.57.0, Loki v6.28.0, OpenTelemetry v0.33.0, Fluent Bit v0.48.9

**Data Services**
- PostgreSQL 15 with pgvector, Redis (Bitnami), NATS with JetStream, MinIO S3

**CI/CD**
- GitHub Actions (ARC), GitLab CI, custom runner images with comprehensive tooling
- Argo Rollouts for Blue-Green deployments with automated E2E testing (Cypress)

**Security**
- SOPS with age encryption, Trivy, TruffleHog, Istio, cert-manager, Teleport agent

## FAQ

**How github runners access clusters?**
- We have a 'cluster-secrets' secret available at namespace level when we have labelled namespace with 'cluster-secrets=true', this secret keys are the keys content of all ./secrets/common/cluster-secret-store/secrets, external-secrets sync vault secrets to this 'cluster-secrets'

- How 'cluster-secrets' is dynamically updated accordingly ./secrets/common/cluster-secret-store/secrets contents? Make plan/apply decodes SOPS secrets and put on ./clusters/tmp, then this data is passed to external-secrets module with 'secret_data' processed here clusters/locals.tf 