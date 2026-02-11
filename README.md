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
- ArgoCD implementation with ApplicationSets and cluster generator for multi-environment deployments
- Sync waves and hooks for ordered, controlled deployments
- Self-healing enabled with automatic drift detection and remediation

**Automated CI/CD Pipelines**

7 GitHub Actions workflows provide comprehensive automation, complemented by local pre-commit hooks for shift-left security:

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| [opentofu.yml](.github/workflows/opentofu.yml) | OpenTofu workflow, plans on PR and apply on merge | PR/Merge to main |
| [ansible.yml](.github/workflows/ansible.yml) | VM provisioning via `[ansible PLAYBOOK]` commit tag | Commit tag detection |
| [build.yml](.github/workflows/build.yml) | Docker image builds on Dockerfile changes | File path changes |
| [sec-trivy.yml](.github/workflows/sec-trivy.yml) | Container and IaC vulnerability scanning | Pull request / Push |
| [sec-trufflehog.yml](.github/workflows/sec-trufflehog.yml) | Secret leak detection in commits | Pull request / Push |
| [conventional-commits.yml](.github/workflows/conventional-commits.yml) | Commit message validation | Pull request |
| [release.yml](.github/workflows/release.yml) | Semantic versioning and changelog generation | Merge to main |

**OpenTofu Workflow Deep Dive** ([opentofu.yml](.github/workflows/opentofu.yml)):

**Plan Phase (on PR)**:
1. Detects changes in `clusters/**` and `secrets/**`
2. Runs `make plan` for all environments
3. Posts truncated plan summary to PR (65KB limit) with full plan in artifacts

**Apply Phase (on merge to main)**:
1. **Capture Before State**: Stores cluster names from `proxmox_cluster_names` output
2. **Apply Changes**: Runs `make apply` for all environments
3. **Capture After State**: Compares cluster outputs to detect changes
4. **Cluster Change Detection**: Identifies NEW/DELETED clusters across sandboxy/tools/observability workspaces
5. **Wait for Cluster Availability**:
   - Monitors Cluster API objects on management cluster (tools)
   - Waits up to 30 minutes with 10-second polling for cluster to reach "Available" status
   - Checks `cluster.cluster.x-k8s.io` CRD status condition
6. **Update Kubeconfigs in SOPS**:
   - Calls [clusters/scripts/update_kubeconfig_sops.sh](clusters/scripts/update_kubeconfig_sops.sh)
   - Extracts kubeconfig from Cluster API secret: `<cluster>-kubeconfig` in namespace `<cluster>`
   - Merges with existing kubeconfig in SOPS file
   - Updates encrypted [secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml](secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml)
   - Commits with message: "chore: Update KUBECONFIG with Cluster API clusters"
7. **Sync to Vault**:
   - Runs `make apply ENV=tools TARGET='module.vault[0]'`
   - External Secrets Operator syncs to Kubernetes secrets in namespaces with `cluster-secrets=true` label
8. **Error Handling**:
   - Kubeconfig update failures post warning comment with manual recovery steps
   - Workflow continues on error to prevent blocking deployments

**External Secrets Automation**:
- When secrets are added/removed in [secrets/](secrets/) directory, OpenTofu automatically updates ExternalSecret objects
- Changes propagate to all clusters via Vault synchronization
- Namespaces with label `cluster-secrets=true` receive updated secrets automatically on 'cluster-secrets' secret
- 'cluster-secrets' secret automatically mounted and available as environment variables on github runners


**Progressive Delivery with Argo Rollouts**

Blue-Green deployment strategy with automated E2E testing and production promotion:

1. **Build Phase**: GitHub Actions ([build.yml](.github/workflows/build.yml)) builds and pushes container image to Harbor registry (`registry.fullstack.pw`)
2. **Dev Deployment**: Pipeline updates dev kustomization with new image tag, ArgoCD syncs to dev cluster
3. **E2E Testing**: Argo Rollouts triggers prePromotionAnalysis running Cypress tests against dev environment
4. **Auto-Promotion**: On test success, postPromotionAnalysis job automatically promotes to prod by updating prod kustomization
5. **Prod Deployment**: ArgoCD syncs prod overlay, Argo Rollouts performs Blue-Green switch

```
Build → Push Image → Update Dev Tag → ArgoCD Sync → Cypress Tests → Update Prod Tag → ArgoCD Sync → Live
```

**ArgoCD ApplicationSet Pattern**:

ApplicationSets use matrix generators combined with the ArgoCD cluster generator to deploy applications across registered clusters:

```yaml
generators:
  - matrix:
      generators:
        - list:  # Applications
            elements:
              - app: cks-backend
                repoURL: https://github.com/fullstack-pw/cks-backend
              - app: cks-frontend
                repoURL: https://github.com/fullstack-pw/cks-frontend
        - clusters:  # Environments resolved from registered clusters
            selector:
              matchExpressions:
                - key: environment
                  operator: In
                  values: [dev, prod]
```

**Bootstrap Architecture**:
- IaC creates an `argocd-bootstrap` Application that recursively syncs the [argocd-apps/](argocd-apps/) directory
- ApplicationSets generate Applications per app/cluster combination
- Standalone Applications for apps that don't fit the matrix pattern
- Auto-sync with pruning and self-healing enabled
- Retry policy: 5 attempts with exponential backoff

**Application Repositories**:
- [cks-backend](https://github.com/fullstack-pw/cks-backend) - Backend APIs with Kustomize overlays
- [cks-frontend](https://github.com/fullstack-pw/cks-frontend) - Web UI with Kustomize overlays
- [cks-terminal-mgmt](https://github.com/fullstack-pw/cks-terminal-mgmt) - Terminal management microservice (sandboxy)

Key components:
- Per-app AnalysisTemplates for Cypress test execution (e.g., `cypress-tests-cks-backend`)
- Per-app AnalysisTemplates for production promotion via git commit automation (e.g., `promote-cks-backend-to-prod`)
- `autoPromotionEnabled: true` for fully automated pipeline
- Prod overlay removes prePromotionAnalysis (tests only run in dev)
- Kustomize overlays for environment-specific configuration

**Self-Hosted Runner Infrastructure**
- Actions Runner Controller (ARC) deployed on tools cluster
- Custom runner image with kubectl, Helm, Terraform, SOPS, Docker CLI, and cloud provider tools
- GitLab CI runners for multi-platform pipeline support
- Centralized reusable workflows in dedicated pipelines repository

**Key Data Flows**:
1. **Infrastructure**: Git → CI/CD → Tools (CAPI) → Workload Clusters
2. **Secrets**: SOPS → CI/CD → Vault → External Secrets → K8s Secrets
3. **Applications**: External Repos → ArgoCD → Deployments
4. **Progressive Delivery**: Build → Dev → Tests → Prod (automated)

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

### Modern Cluster API Provisioning

**Tools cluster serves as Cluster API management cluster**, deploying and managing workload clusters on Proxmox infrastructure:

**Cluster Provisioning Workflow**:
1. **Define Cluster**: Add cluster configuration to `clusters/variables.tf` under tools workspace
2. **CI/CD Apply**: GitHub Actions runs `make apply ENV=tools`, creating Cluster API manifests
3. **Cluster API Provisioning**: Cluster API operator provisions VMs on Proxmox and bootstraps Kubernetes
4. **Automated Kubeconfig Management**:
   - CI/CD detects cluster changes via output comparison (before/after apply)
   - Waits up to 30 minutes for cluster to reach "Available" status
   - Extracts kubeconfig from Cluster API secret (`<cluster>-kubeconfig` in namespace `<cluster>`)
   - Updates SOPS-encrypted [KUBECONFIG.yaml](secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml)
   - Commits changes automatically and syncs to Vault
   - External Secrets Operator propagates to all clusters with `cluster-secrets=true` label
5. **Immediate Availability**: Cluster ready for OpenTofu and CI/CD pipelines

**Cluster API Components**:
- **Management Cluster**: tools (K3s on NODE02)
- **Cluster API Operator**: v1.12.0 with CAPMOX v0.7.5 (Proxmox provider)
- **Supported Distributions**:
  - **Talos Linux**: Immutable infrastructure with declarative configuration (dev cluster)
  - **kubeadm**: Standard Kubernetes with HA support (prod cluster)
  - **K3s, K0s, RKE2**: Additional distributions supported
- **Polymorphic Module**: [modules/apps/kubernetes-cluster](modules/apps/kubernetes-cluster/) supports all cluster types

**Key Script**: [clusters/scripts/update_kubeconfig_sops.sh](clusters/scripts/update_kubeconfig_sops.sh) handles kubeconfig extraction, merging, SOPS encryption, and git commits.

### Ephemeral PR-Based Clusters

**Automatic per-PR test environments** for application repositories, providing isolated Kubernetes clusters for each pull request:

**Architecture**:
- **Cluster Provisioning**: K3s clusters via Cluster API on tools cluster
- **Infrastructure**: OpenTofu with workspace-per-PR isolation ([ephemeral-clusters/opentofu/](ephemeral-clusters/opentofu/))
- **IP Management**: Vault-based IP pool allocation (192.168.1.140-149, 2 IPs per cluster: VIP + node)
- **DNS**: Pi-hole for internal resolution (`pr-<number>-<repo>.ephemeral.fullstack.pw`)
- **Capacity**: 5 concurrent ephemeral clusters maximum

**Workflow Lifecycle** (example: [cks-backend/.github/workflows/ephemeral.yml](https://github.com/fullstack-pw/cks-backend/blob/main/.github/workflows/ephemeral.yml)):

1. **PR Opened**:
   - Check cluster existence via Cluster API
   - Allocate 2 IPs from pool using [ip_pool_manager.sh](clusters/scripts/ip_pool_manager.sh)
   - Render and apply K3s Cluster API manifest
   - Wait for cluster "Available" status (~2 min)
   - Extract kubeconfig on-demand (not stored in Vault)
   - Apply infrastructure via `make ephemeral-apply` (4 phases):
     - Phase 1: Base operators without CRDs (cert-manager, external-dns, external-secrets)
     - Phase 2: Base operators with CRDs (ClusterIssuer, DNSEndpoint, ExternalSecret)
     - Phase 3: Apps without postgres CRDs
     - Phase 4: Apps with postgres CRDs
   - Build and push Docker image (`registry.fullstack.pw/library/<app>:pr-<number>`)
   - Deploy app with `kubectl apply -k kustomize/overlays/ephemeral/`
   - Run Cypress E2E tests in container
   - Post PR comment with environment URL

2. **PR Updated** (new commits):
   - Detect existing cluster (skip provisioning)
   - Build new image with same PR tag
   - Redeploy application
   - Run tests

3. **PR Closed**:
   - Destroy infrastructure with `make ephemeral-destroy`
   - Delete Cluster API cluster object
   - Release IPs back to pool
   - Complete (images remain in Harbor for audit)

**Key Components**:
- **IP Pool Manager**: [clusters/scripts/ip_pool_manager.sh](clusters/scripts/ip_pool_manager.sh) - Vault-based allocation with CAS (Check-And-Set) for concurrency
- **Cluster Template**: [ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl](ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl) - Single-node K3s with external control plane VIP
- **OpenTofu Modules**: Reuse production-proven modules from [modules/apps/](modules/apps/)
- **Makefile Commands**: `ephemeral-init`, `ephemeral-apply`, `ephemeral-destroy`, `ephemeral-workspace`

**Benefits**:
- Isolated test environment per PR
- Automatic provisioning and cleanup
- Full production-like infrastructure (DNS, TLS, secrets)
- No manual intervention required
- Parallel PR testing (up to 5 concurrent)

### Legacy Proxmox/Ansible Provisioning

The `[ansible PLAYBOOK]` pattern remains supported for existing K3s clusters (tools, home, observability):

```bash
git commit -m "feat(proxmox): add k8s-observability VM [ansible k8s-observability]"
```

**Automated Pipeline Chain**:
1. Release workflow generates semantic version tag
2. OpenTofu creates VM from YAML definition in [proxmox/vms/](proxmox/vms/)
3. OpenTofu updates Ansible inventory, preserving `[ansible]` tag in commit message
4. Ansible workflow triggers on tag detection
5. Ansible installs and configures Kubernetes (K3s, kubeadm, vanilla, Talos)
6. Python script extracts kubeconfig, updates IP and context name
7. Kubeconfig merged into central Vault KV store
8. Cluster immediately available to OpenTofu and CI/CD pipelines

This method provisioned all current clusters but is being phased out in favor of Cluster API for new deployments.

### Bootstrap Components

OpenTofu automatically deploys platform services to clusters based on workspace configuration in [clusters/variables.tf](clusters/variables.tf):

**Core Infrastructure** (most clusters):
- cert-manager for automated TLS with Let's Encrypt
- External-DNS for dynamic DNS record management (Cloudflare)
- External Secrets for Vault → Kubernetes secret synchronization
- Metrics Server for resource metrics

**Ingress & Service Mesh**:
- MetalLB for LoadBalancer service type (dev, prod)
- Istio service mesh with mTLS (dev, prod)
- Ingress-NGINX (alternative ingress controller)

**GitOps & CI/CD**:
- ArgoCD for GitOps application delivery (dev, prod, tools)
- GitHub Actions Runner Controller (tools)
- GitLab CI runners (tools)

**Observability**:
- Observability-box (edge collector) on workload clusters
- Full observability stack (Prometheus, Grafana, Jaeger, Loki) on observability cluster

**Storage**:
- Local Path Provisioner for dynamic local storage (dev, prod)
- Longhorn distributed storage (sandboxy for snapshot capability)

**Data Services** (tools cluster):
- CloudNativePG for PostgreSQL
- Redis for caching
- NATS for messaging
- MinIO for S3-compatible object storage

**Cluster Management** (tools cluster only):
- Cluster API Operator v1.12.0 with CAPMOX v0.7.5
- HashiCorp Vault for centralized secrets
- Harbor container registry
- Teleport agent for secure access

Configuration is workspace-specific via `workload` variable - modules only deploy when listed in workspace's workload array.

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

**Pre-Commit Hooks** ([.pre-commit-config.yaml](.pre-commit-config.yaml)):
- SOPS encryption guard preventing unencrypted secrets from being committed
- `detect-secrets` for credential leak detection across all file types
- `detect-private-key` for SSH/PGP key detection
- OpenTofu formatting enforcement via `terraform_fmt`
- Shell script validation via `shellcheck`
- File hygiene checks (trailing whitespace, merge conflicts, large files, YAML/JSON validation)

Setup: `make pre-commit-install` | Run manually: `make pre-commit-run`

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
├── clusters/             # Kubernetes workload definitions (OpenTofu)
│   ├── variables.tf     # Workspace configurations and Cluster API cluster definitions
│   ├── modules.tf       # All module invocations with conditional logic
│   ├── load_secrets.py  # SOPS decryption to JSON
│   └── scripts/
│       └── update_kubeconfig_sops.sh  # Kubeconfig extraction and SOPS management
├── modules/
│   ├── base/            # 10 foundational modules (helm, namespace, ingress, monitoring, credentials, persistence, istio-gateway, istio-virtualservice, cnpg-database, values-template)
│   └── apps/            # 33 application modules categorized as:
│       ├── Cluster: kubernetes-cluster, clusterapi-operator
│       ├── Infrastructure: istio, metallb, external-secrets, cert-manager, externaldns, ingress-nginx, kubelet-csr-approver, local-path-provisioner, metrics-server
│       ├── Data: cloudnative-postgres, cloudnative-postgres-operator, redis, nats, minio
│       ├── Observability: observability, observability-box
│       ├── CI/CD: argocd, github-runner, gitlab-runner
│       ├── Security: vault, teleport-agent, authentik, falco
│       ├── Storage: longhorn, local-path-provisioner
│       ├── Virtualization: kubevirt, kubevirt-operator
│       └── Other: harbor, immich, registry, cluster-autoscaler, oracle-backup
├── proxmox/
│   ├── vms/             # YAML VM definitions for declarative provisioning (legacy)
│   ├── playbooks/       # Ansible configuration playbooks (legacy K3s clusters)
│   └── scripts/         # Automation scripts (Talos, kubeconfig management)
├── argocd-apps/         # GitOps application manifests
│   ├── cks-apps-applicationset.yaml   # CKS platform apps (matrix + cluster generator)
│   ├── cks-terminal-mgmt-sandboxy.yaml # Standalone sandboxy application
│   └── clusters/        # Cluster registration and repo secrets
├── secrets/             # SOPS-encrypted secrets (age encryption)
│   └── common/cluster-secret-store/secrets/  # Cluster-wide secrets synced via External Secrets
├── .github/workflows/   # CI/CD automation pipelines
├── Makefile             # Development commands (plan, apply, init, fmt, validate)
└── docs/                # Technical documentation
```

## Physical Infrastructure

**Compute Resources**
- NODE01: Acer Nitro (i7-4710HQ, 16GB RAM)
- NODE02: HP ED800 G3 Mini (i7-7700T, 32GB RAM)
- NODE03: X99 dual Xeon E5-2699-V3 18-Core, 128GB RAM

**Virtualization**: Proxmox VE managing 10+ VMs across 3 physical hosts

## Kubernetes Environments

| Cluster | Type | Provisioning | Purpose | Node(s) | Key Workloads |
|---------|------|--------------|---------|---------|---------------|
| dev | Talos | Cluster API | Development environment | 1 CP + 2 workers | Development services, Istio service mesh, ArgoCD |
| prod | kubeadm | Cluster API | Production environment | 1 CP + 2 workers | Production services, Istio service mesh, ArgoCD |
| tools | K3s | Legacy Ansible | Platform services & Cluster API management cluster | k8s-tools (single node) | Cluster API operator, CloudNativePG, Redis, NATS, CI/CD runners (GitHub/GitLab), Vault, Harbor, MinIO, ArgoCD, Falco |
| home | K3s | Legacy Ansible | Home automation | k8s-home (single node) | Immich photo management, External Secrets |
| observability | K3s | Legacy Ansible | Central monitoring hub | k8s-observability (single node) | Prometheus (kube-prometheus-stack), Grafana, Jaeger, Loki, OpenTelemetry Collector |
| sandboxy | K3s | Legacy Ansible | CKS (Certified Kubernetes Security) platform | k8s-sandbox (single node) | KubeVirt for VM virtualization, Longhorn for snapshot-based storage, cks-terminal-mgmt for browser-based terminal access via ttyd, maintains pool of standby VMs for instant CKS scenario provisioning with rapid reset |

## Technology Stack

**Infrastructure Layer**
- OpenTofu 1.11.3+
- Ansible (legacy cluster provisioning)
- Proxmox VE (hypervisor)
- Cluster API v1.12.0 with CAPMOX v0.7.5 (Proxmox provider)

**Kubernetes Distributions**
- K3s (lightweight, single-node)
- kubeadm (standard multi-node)
- Talos Linux (immutable infrastructure)

**Platform Services**
- ArgoCD 7.7.12 (GitOps)
- HashiCorp Vault (secrets management)
- cert-manager (TLS automation)
- External Secrets Operator (Vault → K8s sync)
- Istio (service mesh)
- MetalLB (LoadBalancer)

**Observability**
- Prometheus (kube-prometheus-stack v79.0.1)
- Grafana (dashboards)
- Jaeger v2.57.0 (distributed tracing)
- Loki v6.28.0 (log aggregation)
- OpenTelemetry Collector v0.33.0 (telemetry ingestion)
- Fluent Bit v0.48.9 (log forwarding)

**Data Services**
- CloudNativePG operator (PostgreSQL 15+ with pgvector, automated backups, managed roles/databases)
- Redis (Bitnami)
- NATS with JetStream (messaging)
- MinIO (S3-compatible object storage)

**CI/CD**
- GitHub Actions with Actions Runner Controller (ARC)
- GitLab CI runners
- Argo Rollouts (Blue-Green deployments with automated E2E testing via Cypress)
- Harbor (container registry)
- Custom runner images with kubectl, Helm, OpenTofu, SOPS, Docker CLI

**Security**
- SOPS with age encryption
- Pre-commit hooks (SOPS guard, detect-secrets, detect-private-key, shellcheck)
- Trivy (vulnerability scanning)
- TruffleHog (secret leak detection)
- Falco (runtime security monitoring via eBPF)
- Istio mTLS (service mesh security)
- cert-manager with Let's Encrypt
- Teleport agent (secure access)
- Authentik (identity provider)

## FAQ

### How do GitHub runners access clusters?

Clusters are accessible via the `cluster-secrets` Kubernetes secret deployed to namespaces with label `cluster-secrets=true`. This secret contains:
- `KUBECONFIG`: Combined kubeconfig for all clusters
- All other secrets from [secrets/common/cluster-secret-store/secrets/](secrets/common/cluster-secret-store/secrets/)

**Synchronization Flow**:
1. SOPS-encrypted secrets stored in [secrets/](secrets/) directory
2. `make plan/apply` runs [clusters/load_secrets.py](clusters/load_secrets.py) to decrypt secrets to `clusters/tmp/secrets.json`
3. OpenTofu processes secrets via `locals.tf` and passes to External Secrets module
4. External Secrets module creates ExternalSecret objects referencing Vault paths
5. External Secrets Operator syncs from Vault to Kubernetes secrets
6. Namespaces with `cluster-secrets=true` label automatically receive `cluster-secrets` secret

**Automatic Secret Updates**:
When secrets are added/removed in code:
- OpenTofu detects changes and updates ExternalSecret objects
- External Secrets Operator automatically propagates changes to all clusters
- No manual intervention required - fully automated across all environments

### How is kubeconfig managed for Cluster API clusters?

**Automated Workflow** (triggered on cluster changes):
1. CI/CD detects cluster changes via output comparison (before/after apply)
2. Waits up to 30 minutes for Cluster API cluster to reach "Available" status
3. [clusters/scripts/update_kubeconfig_sops.sh](clusters/scripts/update_kubeconfig_sops.sh) extracts kubeconfig from Cluster API secret
4. Merges with existing kubeconfig in [secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml](secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml)
5. Git commit: "chore: Update KUBECONFIG with Cluster API clusters"
6. Syncs to Vault via `make apply ENV=tools TARGET='module.vault[0]'`
7. External Secrets propagates to all clusters

**Manual Recovery** (if automation fails):
```bash
./clusters/scripts/update_kubeconfig_sops.sh \
  --cluster-name <cluster> \
  --namespace <cluster> \
  --management-context tools
```

### How do I add a new Cluster API cluster?

1. Add cluster configuration to [clusters/variables.tf](clusters/variables.tf) under tools workspace:
```hcl
tools = {
  kubernetes-cluster = [
    {
      cluster_type = "talos"  # or "kubeadm"
      name = "new-cluster"
      kubernetes_version = "v1.33.0"
      control_plane_endpoint_ip = "192.168.1.80"
      ip_range_start = "192.168.1.81"
      ip_range_end = "192.168.1.89"
      gateway = "192.168.1.1"
      prefix = 24
      dns_servers = ["192.168.1.3", "8.8.4.4"]

      source_node = "node03"
      template_id = 9005
      allowed_nodes = ["node03"]

      cp_replicas = 1
      wk_replicas = 2

      cp_disk_size = 20
      cp_memory = 4096
      cp_cores = 4
      wk_disk_size = 30
      wk_memory = 8192
      wk_cores = 8
    }
  ]
}
```
2. Commit and push to trigger CI/CD
3. CI/CD automatically provisions cluster and updates kubeconfig in Vault
4. Cluster immediately available to OpenTofu and CI/CD pipelines

### How do I add a new module to an environment?

1. Add module name to workspace's `workload` list in [clusters/variables.tf](clusters/variables.tf):
```hcl
variable "workload" {
  default = {
    dev = ["existing-module", "new-module"]
  }
}
```
2. Add module configuration under workspace in `config` variable:
```hcl
variable "config" {
  default = {
    dev = {
      new-module = {
        # module-specific settings
      }
    }
  }
}
```
3. Verify module exists in [clusters/modules.tf](clusters/modules.tf) with conditional count:
```hcl
module "new_module" {
  count  = contains(local.workload, "new-module") ? 1 : 0
  source = "../modules/apps/new-module"
}
```
4. Run `make plan ENV=dev` to preview, then `make apply ENV=dev` to deploy

### What is sandboxy cluster used for?

The sandboxy cluster serves mostly to **CKS (Certified Kubernetes Security) training platform**:

**Architecture**:
- KubeVirt for VM virtualization on Kubernetes
- Longhorn for distributed storage with snapshot capability
- Pool of standby VMs ready for instant provisioning

**Workflow**:
1. CKS maintains pool of standby VMs (running on KubeVirt)
2. User starts a CKS scenario
3. VM instantly provisioned from pool (no wait time)
4. User opens terminal tabs (multi-terminal support via cks-terminal-mgmt + ttyd)
5. User completes scenario exercises
6. CKS triggers Longhorn snapshot restore
7. VM reset to clean state and returned to pool
8. Rapid reset enables high-throughput scenario execution

**Terminal Access**:
- [cks-terminal-mgmt](https://github.com/fullstack-pw/cks-terminal-mgmt) runs on sandboxy alongside KubeVirt VMs
- Spawns ttyd processes on-demand for SSH connections to VMs
- Frontend embeds terminals via iframe with multi-tab support (multiple terminals per VM)

This architecture provides instant scenario availability and eliminates waiting for VM provisioning/cleanup.
