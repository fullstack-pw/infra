# fullstack-pw: Cloud-Native DevOps Portfolio

Production-grade homelab platform demonstrating enterprise DevOps practices, cloud-native architectures, and infrastructure automation. Built as a comprehensive portfolio showcasing modern software engineering, SRE, and platform engineering capabilities.

## Platform Overview

The fullstack.pw organization encompasses a complete infrastructure and application ecosystem built on Kubernetes, implementing:

- **Multi-environment Kubernetes clusters** with Cluster API-based automated provisioning and lifecycle management
- **Ephemeral PR-based test environments** with automatic cluster provisioning, deployment, testing, and cleanup per pull request
- **Infrastructure as Code** with OpenTofu modular architecture
- **GitOps-driven continuous deployment** with ArgoCD ApplicationSets, cluster generator, and progressive delivery via Argo Rollouts
- **Comprehensive observability** using Prometheus, Grafana, Jaeger, Loki, and OpenTelemetry with hub-and-spoke architecture
- **Self-hosted CI/CD infrastructure** with GitHub Actions Runner Controller (ARC) and GitLab runners
- **Defense-in-depth security** with Vault, cert-manager, Istio service mesh, SOPS encryption, and External Secrets Operator
- **Automated cluster bootstrapping** via Cluster API on tools cluster (management cluster)
- **Automated kubeconfig management** with SOPS encryption and Vault synchronization
- **Progressive delivery pipelines** with automated E2E testing and blue-green deployments

## Architecture

TBD

### Physical Infrastructure

**Compute Nodes**
- NODE01: Acer Nitro (i7-4710HQ, 16GB RAM)
- NODE02: HP ED800 G3 Mini (i7-7700T, 32GB RAM) with USB-attached storage
- NODE03: X99 dual Xeon E5-2699-V3 18-Core, 128GB RAM

**Virtualization**: Proxmox VE managing VMs across physical hosts with YAML-driven declarative provisioning

### Network Architecture

- Cloudflare: DNS, CDN, and WAF for public-facing services with automatic DNS record management
- Pi-hole: Internal DNS server with ad-blocking for homelab name resolution
- MetalLB: Bare metal load balancer for Kubernetes LoadBalancer service type
- External-DNS: Automated DNS record lifecycle management with TXT ownership verification

### Kubernetes Cluster Topology

| Cluster | Distribution | Provisioning | Purpose | Infrastructure | Key Platform Components |
|---------|--------------|--------------|---------|----------------|-------------------------|
| dev | Talos Linux | Cluster API | Development environment | 1 CP + 2 workers (dynamic) | Istio service mesh, ArgoCD, development workloads |
| prod | kubeadm | Cluster API | Production services | 1 CP + 2 workers (dynamic) | Istio service mesh, ArgoCD, production applications |
| tools | K3s | Legacy Ansible | Platform infrastructure & Cluster API management cluster | k8s-tools (single node) | Cluster API operator, CloudNativePG, Redis, NATS, Vault, Harbor, MinIO, CI/CD runners (GitHub/GitLab), ArgoCD, Falco |
| home | K3s | Legacy Ansible | Home automation | k8s-home (single node) | Immich photo management, External Secrets |
| observability | K3s | Legacy Ansible | Central telemetry hub | k8s-observability (single node) | Prometheus, Grafana, Jaeger, Loki, OpenTelemetry Collector |
| sandboxy | K3s | Legacy Ansible | CKS training platform | k8s-sandbox (single node) | KubeVirt for VM virtualization, Longhorn for snapshot-based storage, cks-terminal-mgmt for browser-based terminal access, pool of standby VMs for instant CKS scenario provisioning |
| pr-* (ephemeral) | K3s | Cluster API | Temporary PR test environments | Single node per PR (dynamic, 5 max concurrent) | cert-manager, external-dns, external-secrets, CloudNativePG, application under test |

**Note**: dev and prod clusters are managed by Cluster API operator running on tools cluster. Talos provides immutable infrastructure, while kubeadm offers standard Kubernetes. Legacy clusters (tools, home, observability, sandboxy) provisioned via Proxmox/Ansible workflow. Ephemeral clusters are automatically created per PR in application repositories and destroyed when PR closes.

## Repository Organization

### Infrastructure & Platform

**[infra](https://github.com/fullstack-pw/infra)**: Complete infrastructure-as-code repository
- OpenTofu modules for Kubernetes workload deployment
- Cluster API integration for automated cluster provisioning (Talos Linux, kubeadm)
- Ansible playbooks for legacy cluster bootstrapping (K3s clusters)
- GitHub Actions workflows for automated infrastructure lifecycle with kubeconfig management
- SOPS-encrypted secrets management with age encryption and Vault synchronization

**[pipelines](https://github.com/fullstack-pw/pipelines)**: Centralized CI/CD workflows
- Reusable GitHub Actions workflows for application deployment
- Multi-environment Kustomize-based deployment pipelines
- Security scanning and validation workflows
- Standardized build and release processes

### Application Repositories

**[cks-backend](https://github.com/fullstack-pw/cks-backend)**: CKS training platform backend
- Go-based backend implementing cluster pool management for Kubernetes security training
- KubeVirt integration for VM-based Kubernetes cluster provisioning
- Snapshot-based restoration achieving sub-second session allocation
- Unified validation engine supporting resource checks, script execution, and file content validation
- WebSocket terminal access with deterministic terminal IDs for reconnection

**[cks-frontend](https://github.com/fullstack-pw/cks-frontend)**: CKS training platform frontend
- Next.js 14 application with browser-based terminal emulation using xterm.js
- SWR-based state management with optimistic updates
- Multi-stage Docker build achieving 70% image size reduction via standalone output
- Admin dashboard for cluster pool and session management

**[cks-terminal-mgmt](https://github.com/fullstack-pw/cks-terminal-mgmt)**: Terminal management microservice
- Go-based service running on sandboxy cluster alongside KubeVirt VMs
- Spawns ttyd processes on-demand for SSH connections to VMs
- Browser-based terminal access via iframe with multi-tab support

## Platform Components

### Infrastructure Automation

| Component | Technology | Implementation |
|-----------|-----------|----------------|
| k8s Cluster Provisioning | Cluster API v1.12.0 + CAPMOX v0.7.5 | Tools cluster manages dev/prod cluster lifecycle on Proxmox |
| VM Provisioning | OpenTofu + Proxmox | YAML-driven declarative VM definitions (legacy) |
| Configuration Management | Ansible | Idempotent playbooks for legacy K3s clusters |
| State Management | OpenTofu + MinIO S3 | Remote state with workspace isolation, daily backup to Oracle Cloud |
| Kubeconfig Management | Automated via CI/CD | SOPS encryption, Cluster API secret extraction, Vault sync |

### Kubernetes Platform Services

| Service | Purpose | Implementation | Access |
|---------|---------|----------------|--------|
| cert-manager | Automated TLS certificate management | Let's Encrypt with DNS-01 challenge | Cluster-internal |
| External-DNS | Dynamic DNS record management | Cloudflare and Pi-hole integration | Cluster-internal |
| External Secrets | Vault to Kubernetes secret sync | ClusterSecretStore with namespace selector | Cluster-internal |
| Istio | Service mesh for dev cluster | mTLS, traffic management, observability | Gateway at dev cluster |
| NGINX Ingress | Ingress controller for other clusters | HTTP/HTTPS routing with TLS termination | Multiple clusters |
| MetalLB | LoadBalancer for bare metal | Layer 2 mode for service exposure | Vanilla K8s clusters |
| KubeVirt | Virtual machine orchestration | Nested VMs on Kubernetes | sandboxy cluster |

### Storage & Registry Infrastructure

| Service | Technology | Purpose | URL |
|---------|-----------|---------|-----|
| MinIO | S3-compatible object storage | Terraform state backend, backups | [s3.fullstack.pw](https://s3.fullstack.pw) |
| Harbor | Enterprise container registry | Multi-tenant registry with security scanning, image replication | [registry.fullstack.pw](https://registry.fullstack.pw) |
| Longhorn | Distributed block storage | Persistent volumes for KubeVirt VMs on sandboxy cluster | [longhorn.fullstack.pw](https://longhorn.fullstack.pw) |

### Secrets & Security

| Component | Implementation | Purpose | Location |
|-----------|---------------|---------|----------|
| HashiCorp Vault | KV v2 engine with K8s auth | Runtime secret storage and distribution | [vault.fullstack.pw](https://vault.fullstack.pw) |
| External Secrets Operator | ClusterSecretStore | Vault to Kubernetes secret synchronization | All clusters |
| SOPS + age | Encrypted YAML in Git | Secrets at rest in version control | infra repository |
| cert-manager | Let's Encrypt automation | TLS certificate lifecycle management | All clusters |
| Trivy | Security scanner | Container and IaC vulnerability scanning | CI/CD pipelines |

### CI/CD Infrastructure

| Component | Implementation | Deployment |
|-----------|---------------|------------|
| GitHub Actions Runners | Actions Runner Controller (ARC) | tools cluster |
| GitLab Runners | GitLab Runner with Docker executor | tools cluster |
| Custom Runner Image | Docker image with kubectl, Helm, Terraform, SOPS | Harbor registry |
| Reusable Workflows | Shared GitHub Actions workflows | [pipelines](https://github.com/fullstack-pw/pipelines) |

### Observability Stack

**Central Hub (Observability Cluster)**

| Component | Version | Purpose | Access |
|-----------|---------|---------|--------|
| Prometheus | kube-prometheus-stack v79.0.1 | Multi-cluster metrics aggregation | [prometheus.fullstack.pw](https://prometheus.fullstack.pw) |
| Grafana | Bundled with kube-prometheus-stack | Unified dashboards and visualization | [grafana.fullstack.pw](https://grafana.fullstack.pw) |
| Jaeger | v2.57.0 | Distributed tracing backend | [jaeger.fullstack.pw](https://jaeger.fullstack.pw) |
| Loki | v6.28.0 | Centralized log aggregation | [loki.fullstack.pw](https://loki.fullstack.pw) |
| OpenTelemetry Collector | v0.33.0 | Central telemetry ingestion and processing | Cluster-internal |

**Edge Collectors (All Other Clusters)**

Deployed via observability-box Terraform module:
- Prometheus with remote write to central hub
- Fluent Bit v0.48.9 for log forwarding to Loki
- OpenTelemetry Collector for trace and metric forwarding
- Automatic cluster labeling for multi-tenant observability

**Data Flow Architecture**
```
Application Pods → ServiceMonitor/PodMonitor → Prometheus (edge)
                → Fluent Bit → Loki (central)
                → OTel Collector (edge) → Jaeger (central)

Edge Prometheus → Remote Write → Central Prometheus → Grafana
```

### Data Services

| Service | Technology | Purpose | Deployment |
|---------|-----------|---------|------------|
| PostgreSQL | CloudNativePG operator (PostgreSQL 15+ with pgvector) | Managed PostgreSQL with automated backups, roles, and credential export | tools, dev, prod clusters |
| Redis | Bitnami Redis chart | Caching and session storage | tools cluster |
| NATS | NATS with JetStream | Message broker and streaming | tools cluster |

### Home Services

| Service | Purpose | Technology | Access |
|---------|---------|-----------|--------|
| Immich | Self-hosted photo and video management | Container deployment with external storage | [immich.fullstack.pw](https://immich.fullstack.pw) |

## CI/CD Pipeline Architecture

**Build Stage**
- Conventional commit validation
- Automated unit and integration testing
- Container image building with multi-stage Dockerfiles
- Trivy security scanning (containers and IaC)
- TruffleHog secret leak detection
- Image pushing to Harbor/Docker Registry with SHA tagging

**Deploy Stage**
- OpenTofu plan on pull requests with change detection
- OpenTofu apply on merge with cluster change detection (before/after output comparison)
- Automated Cluster API cluster provisioning on tools cluster
- Cluster availability wait (30 minutes with polling)
- Automated kubeconfig extraction and SOPS encryption
- Git commit and Vault synchronization
- Kustomize overlay selection based on environment
- ArgoCD application sync with health checks
- Progressive environment promotion (dev → prod) with Argo Rollouts
- External Secrets synchronization from Vault to all clusters

**Test Stage**
- Infrastructure validation tests
- End-to-end testing with Cypress
- Security posture validation
- SARIF output to GitHub Security tab

**Automation Workflows**

**Infrastructure Repository** (7 workflows):
- opentofu.yml: Plan on PR, apply on merge with cluster change detection and kubeconfig automation
- ansible.yml: Legacy cluster provisioning via `[ansible PLAYBOOK]` commit tag
- build.yml: Container image build and push to Harbor registry
- sec-trivy.yml: Container and IaC vulnerability scanning
- sec-trufflehog.yml: Secret leak detection in commits
- conventional-commits.yml: Commit message validation
- release.yml: Semantic versioning and changelog generation

**Application Repositories** (ephemeral.yml):
- Ephemeral PR-based cluster provisioning: Automatic Kubernetes cluster creation, infrastructure deployment, application build/deploy, E2E testing, and cleanup lifecycle per pull request

## DevOps Practices Demonstrated

**Infrastructure as Code**
- Two-tier OpenTofu module architecture
- Cluster API-based cluster provisioning with automated kubeconfig management
- YAML-driven VM provisioning with dynamic resource creation (legacy)
- Automated state backup to Oracle Cloud Object Storage
- Workspace-based environment isolation

**GitOps Methodology**
- Git as single source of truth for all infrastructure
- ArgoCD with ApplicationSets, cluster generator, and sync waves
- Automated drift detection and remediation
- Pull request-based change management with automated validation

**Continuous Observability**
- Hub-and-spoke telemetry architecture
- OpenTelemetry instrumentation in applications
- Distributed tracing with correlation across services
- Custom dashboards and alerting rules (PostgreSQL, Redis, NATS)
- Structured JSON logging with trace context

**Security Best Practices**
- Multi-layered secrets management (SOPS → Vault → External Secrets)
- Automated TLS certificate lifecycle
- Service mesh with mTLS capability
- Continuous vulnerability scanning
- Least-privilege RBAC and Vault policies
- Non-root container execution

**Automation & Self-Service**
- Cluster API-based automated cluster provisioning on Proxmox
- Automated kubeconfig extraction, SOPS encryption, and Vault synchronization
- Single-commit VM-to-Kubernetes provisioning workflow (legacy)
- Self-healing via Kubernetes probes and ArgoCD sync
- Automated DNS and certificate management
- Progressive delivery with automated E2E testing and blue-green deployments

**Resilience & Recovery**
- Multi-cluster architecture for blast radius isolation
- Automated backup strategies (state, databases, storage)
- Complete infrastructure reproducible from Git
- High availability with replica distribution
- Disaster recovery procedures documented

## Module Architecture

**Base Modules (10 building blocks)**
- namespace: Kubernetes namespace with labels and annotations
- helm: Standardized Helm release deployment
- values-template: Dynamic Helm values rendering
- ingress: Ingress resource with TLS configuration
- persistence: PersistentVolumeClaim management
- credentials: Secret and ConfigMap handling
- monitoring: ServiceMonitor and PodMonitor creation
- istio-gateway: Istio Gateway resource
- istio-virtualservice: Istio VirtualService routing
- cnpg-database: CloudNativePG database management

**Application Modules (33 complete solutions)**

Cluster Provisioning:
- kubernetes-cluster (Talos, kubeadm, K3s, K0s, RKE2), clusterapi-operator

Platform Infrastructure:
- cert-manager, externaldns, external-secrets, argocd
- istio, ingress-nginx, metallb, kubelet-csr-approver, metrics-server, local-path-provisioner

Observability:
- observability (central hub), observability-box (edge collector)

CI/CD:
- github-runner (ARC), gitlab-runner

Storage & Registry:
- harbor, minio, longhorn, local-path-provisioner

Data Services:
- cloudnative-postgres, cloudnative-postgres-operator, redis, nats

Security:
- vault, teleport-agent, authentik, falco

Virtualization:
- kubevirt, kubevirt-operator

Other:
- immich, registry, cluster-autoscaler, oracle-backup

## Technologies & Tools

**Infrastructure & Virtualization**
- Proxmox VE, OpenTofu 1.11.3+, Ansible (legacy clusters), cloud-init
- Cluster API v1.12.0 with CAPMOX v0.7.5 (Proxmox provider)

**Kubernetes Ecosystem**
- K3s (lightweight), kubeadm (standard multi-node), Talos Linux (immutable), KubeVirt (VMs)
- ArgoCD 7.7.12, Argo Rollouts (progressive delivery), Helm, Kustomize, kubectl

**Observability & Monitoring**
- Prometheus (kube-prometheus-stack v79.0.1), Grafana
- Jaeger v2.57.0, OpenTelemetry v0.33.0, Loki v6.28.0, Fluent Bit v0.48.9
- ServiceMonitor, PodMonitor, PrometheusRule CRDs

**Security & Compliance**
- HashiCorp Vault, SOPS with age encryption, cert-manager
- Istio service mesh, External Secrets Operator
- Falco (runtime security monitoring via eBPF)
- Pre-commit hooks (SOPS guard, detect-secrets, detect-private-key, shellcheck)
- Trivy, TruffleHog, RBAC, Vault policies

**Networking & Service Mesh**
- Istio, NGINX Ingress, HAProxy, MetalLB
- External-DNS (Cloudflare + Pi-hole)
- Cloudflare (DNS, CDN, WAF)

**Storage Solutions**
- MinIO S3, Harbor, Docker Registry
- Longhorn distributed storage
- USB-attached storage for home services

**Data & Messaging**
- CloudNativePG operator (PostgreSQL 15+ with pgvector, automated backups, managed roles)
- Redis (Bitnami charts)
- NATS with JetStream streaming

**CI/CD & Automation**
- GitHub Actions with Actions Runner Controller
- GitLab CI with self-hosted runners
- Custom runner images with comprehensive tooling
- Semantic versioning and conventional commits

**Programming & Development**
- Go (microservices with OTel instrumentation)
- JavaScript/Node.js, Python
- Dockerfile multi-stage builds

## Documentation & Resources

**Infrastructure Documentation**
- [Infrastructure README](https://github.com/fullstack-pw/infra): Complete infrastructure overview

**Application Documentation**
- [Pipelines Documentation](https://github.com/fullstack-pw/pipelines): Reusable workflow specifications
- [CKS Backend](https://github.com/fullstack-pw/cks-backend): CKS training platform backend implementation
- [CKS Frontend](https://github.com/fullstack-pw/cks-frontend): CKS training platform web interface
