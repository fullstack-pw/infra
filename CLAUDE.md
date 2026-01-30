# CLAUDE.md

## Rules

* You are forbidden to add 'Claude' reference as author to anywhere (commits, docs, etc)
* You don't put commentaries on code
* You don't use emoticons
* When you run make apply or make plan, make already runs the script to decode vault secrets to be available when OpenTofu runs
* To plan OpenTofu you run 'make plan ENV=environment' from /home/pedro/repos/infra 
* To apply OpenTofu you run 'make apply ENV=environment' from /home/pedro/repos/infra 
* You're not allowed to commit and push directly neither mention yourself
* You're not allowed to create/edit resources directly via kubectl/vault, you can only make these type of changes via OpenTofu or manually like this to test something
* At the end of your task you always review what was done and repo README to properly update it

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a production-grade infrastructure-as-code repository for managing Kubernetes clusters and applications on Proxmox VE using OpenTofu, with GitOps workflows via ArgoCD.

**Key Architecture:**
- Two-tier OpenTofu structure: 11 base modules, 28+ application modules
- **Cluster provisioning via Cluster API** installed on tools cluster (replaces legacy Proxmox OpenTofu + Ansible workflow)
- Multi-environment isolation using OpenTofu workspaces (dev, stg, prod, tools, home, observability, sandboxy)
- Secrets managed via SOPS (age encryption) and HashiCorp Vault (runtime)
- Kubernetes distributions: K3s (single-node, legacy), Talos Linux (Cluster API), vanilla Kubernetes (Cluster API with kubeadm)

## Common Development Commands

### OpenTofu Operations

**Clusters (Kubernetes workloads):**
```bash
# Plan/apply for specific environment
make plan ENV=dev
make apply ENV=dev

# Plan/apply all environments
make plan
make apply

# Initialize OpenTofu
make init

# Format and validate
make fmt
make validate

```

**Proxmox (VM infrastructure - LEGACY, mostly deprecated, provision VMs with terraform and configure with ansible):**
```bash
# Legacy VM provisioning (rarely used now)
make proxmox-plan
make proxmox-apply
make proxmox-init

# Note: Cluster provisioning now handled via Cluster API in clusters/ directory
```

### Secrets Management

```bash
# Create new secret
./secret_new.sh path/to/secret.yaml

# Edit existing secret
./secret_edit.sh path/to/secret.yaml

# View secret without editing
./secret_view.sh path/to/secret.yaml
```

**SOPS Configuration:**
- Age public key: `age15vvdhaj90s3nru2zw4p2a9yvdrv6alfg0d6ea6zxpx3eagyqfqlsgdytsp`
- All secrets in `secrets/` directory are encrypted with SOPS
- Make command decodes secrets to /home/pedro/repos/infra/clusters/tmp before planning or applying
- `.sops.yaml` defines encryption rules

### Kubernetes Cluster Management

**Update Talos kubeconfigs in Vault:**
```bash
# Build the Go tool
make build-kubeconfig-tool

# Update all Talos cluster kubeconfigs
make update-kubeconfigs

# Update for specific environment
make update-kubeconfigs ENV=sandboxy

# Test without updating Vault
make test-kubeconfig-update
```

## Key Architectural Patterns

### Two-Tier OpenTofu Module System

**Base Modules** (`modules/base/`):
- Foundational building blocks: `helm`, `namespace`, `ingress`, `monitoring`, `credentials`, `persistence`, `values-template`, `istio-gateway`, `istio-virtualservice`
- Used by application modules to create common resources

**Application Modules** (`modules/apps/`):
- Complete application deployments: `argocd`, `vault`, `postgres`, `redis`, `nats`, `minio`, `externaldns`, `cert_manager`, `external-secrets`, `istio`, `observability`, `github-runner`, `gitlab-runner`, `harbor`, `immich`, `kubevirt`, `longhorn`, `teleport-agent`, `OpenTofu-state-backup`, `clusterapi-operator`, `proxmox-talos-cluster`, `proxmox-kubeadm-cluster`
- Conditionally deployed based on workspace configuration

### Workspace-Based Environment Isolation

Each OpenTofu workspace represents an environment. Configuration is defined in `clusters/variables.tf`:

```hcl
variable "workload" {
  # Maps workspace name to list of modules to deploy
  default = {
    dev = ["externaldns", "cert_manager", "istio", "argocd", ...]
    tools = ["postgres", "redis", "vault", "github_runner", ...]
  }
}

variable "config" {
  # Maps workspace to environment-specific settings
  default = {
    dev = {
      kubernetes_context = "dev"
      install_crd = true
      argocd_domain = "dev.argocd.fullstack.pw"
    }
  }
}
```

**Pattern:**
- Modules check `contains(local.workload, "module_name")` to conditionally create resources
- `terraform.workspace` provides current environment name
- Single `clusters/modules.tf` defines all module invocations with conditional counts

### YAML-Driven VM Provisioning

VMs are defined declaratively in `proxmox/vms/*.yaml`:

```yaml
name: k8s-dev
target_node: node01
cores: 4
memory: 8192
clone: ubuntu-k3s
ipconfig0: ip=192.168.1.71/24,gw=192.168.1.1
```

OpenTofu reads all YAML files and creates VMs via `for_each`:

```hcl
data "local_file" "yaml_files" {
  for_each = fileset("${path.module}/vms", "*.yaml")
  filename = "${path.module}/vms/${each.key}"
}

resource "proxmox_vm_qemu" "vm" {
  for_each = { for file, content in data.local_file.yaml_files :
               file => yamldecode(content.content) }
  # ...
}
```

### Modern Cluster Provisioning with Cluster API

**Current approach** (replaces legacy Proxmox OpenTofu + Ansible):

1. Clusters defined in `clusters/variables.tf` under workspace's `proxmox-talos-cluster` or `proxmox-kubeadm-cluster` config
2. OpenTofu creates Cluster API resources on tools cluster (management cluster)
3. Cluster API provisions VMs and bootstraps Kubernetes automatically
4. OpenTofu workflow detects new/changed clusters via output comparison
5. `cicd-update-kubeconfig` Go tool extracts kubeconfigs from Cluster API secrets
6. Kubeconfigs merged and stored in Vault at `kv/cluster-secret-store/secrets`
7. Cluster immediately available to OpenTofu and CI/CD

**Key Workflow Files:**
- `.github/workflows/OpenTofu.yml` - Main deployment pipeline with kubeconfig update step
- `.github/workflows/release.yml` - Semantic versioning and changelog generation
- `.github/workflows/ansible.yml` - Legacy workflow (still used for K3s clusters)

**Legacy Pattern (deprecated for new clusters):**
The `[ansible PLAYBOOK]` pattern is no longer the primary provisioning method but remains for existing K3s clusters (dev, tools, home, observability).

### Secrets Lifecycle

```
Developer → /home/pedro/repos/infra/secret*.sh → SOPS-encrypted YAML → Git → CI/CD (decrypt) → Vault → External Secrets Operator → K8s Secrets → Pods
```

**In OpenTofu:**
```hcl
# clusters/load_secrets.py reads SOPS secrets and outputs JSON
locals {
  secrets_json = jsondecode(file("${path.module}/secrets.json"))
}

# Modules reference secrets
vault_token = local.secrets_json["kv/cluster-secret-store/secrets/VAULT_TOKEN"]["VAULT_TOKEN"]
```

**In CI/CD:**
- `VAULT_TOKEN` stored in GitHub Secrets
- Kubeconfig managed in Vault at `kv/cluster-secret-store/secrets`
- External Secrets syncs from Vault to K8s namespaces with label `cluster-secrets=true`

### Cluster API Integration (Current Standard)

**Management Cluster:**
- Cluster API operator installed on `tools` cluster
- Manages infrastructure providers (Proxmox) and bootstrap providers (Talos, kubeadm)
- CAPI v1.9.4 for compatibility with CAPMOX v0.7.x

**Talos Linux Clusters:**
- Defined via `modules/apps/proxmox-talos-cluster`
- Immutable infrastructure with declarative configuration
- Primary choice for new clusters in `sandboxy` workspace
- Kubeconfigs automatically extracted and synced to Vault

**Kubeadm Clusters:**
- Defined via `modules/apps/proxmox-kubeadm-cluster`
- Multi-node HA support with customizable control plane
- Standard Kubernetes distribution

**Kubeconfig Lifecycle:**
1. Cluster API creates secret `<cluster>-kubeconfig` in namespace `<cluster>`
2. OpenTofu detects cluster changes via output comparison (before/after apply)
3. `cicd-update-kubeconfig` tool:
   - **CREATE/UPDATE**: Extracts kubeconfig, merges with existing Vault config, updates Vault
   - **DELETE**: Removes cluster entries from Vault kubeconfig
4. Tool retries on failure (3 attempts, 30s intervals) for cluster readiness
5. CI/CD continues on kubeconfig update failure (logged as warning)

### Conditional Resource Creation

Many modules support chicken-and-egg scenarios:

```hcl
# Create Istio CRDs first, then set create_default_gateway = true
create_default_gateway = true  # Start with false, change after CRDs exist

# Install CRDs only on first apply
install_crd = var.config[OpenTofu.workspace].install_crd
```

**Pattern:** Comments indicate TODO items for multi-step deployments.

### Hub-and-Spoke Observability

**Hub Cluster (observability):**
- Prometheus (kube-prometheus-stack)
- Grafana for multi-cluster dashboards
- Jaeger for distributed tracing
- Loki for log aggregation

**Spoke Clusters (all others):**
- Fluent Bit forwards logs to Loki
- Prometheus remote writes to hub
- OpenTelemetry Collector forwards traces
- Deployed via `observability-box` module

## Important File Locations

**OpenTofu Configuration:**
- `clusters/modules.tf` - All module invocations (main orchestration file)
- `clusters/variables.tf` - Workspace configurations, workload definitions, and **Cluster API cluster definitions**
- `clusters/providers.tf` - Kubernetes, Helm, Kubectl providers
- `clusters/load_secrets.py` - Decrypts SOPS secrets for OpenTofu

**Cluster API Modules:**
- `modules/apps/proxmox-talos-cluster/` - Talos cluster definitions
- `modules/apps/proxmox-kubeadm-cluster/` - Kubeadm cluster definitions
- `modules/apps/clusterapi-operator/` - Cluster API operator deployment

**Legacy VM and Ansible (for K3s clusters):**
- `proxmox/vms/*.yaml` - Legacy VM definitions (rarely used)
- `proxmox/playbooks/*.yml` - Ansible playbooks for K3s cluster setup
- `proxmox/scripts/` - Helper scripts

**CI/CD:**
- `.github/workflows/OpenTofu.yml` - Main deployment workflow with kubeconfig update automation
- `.github/workflows/ansible.yml` - Legacy Ansible automation (still used for K3s)

**ArgoCD:**
- `argocd-apps/` - GitOps application manifests

## Critical Patterns When Making Changes

### Adding a New Module

1. Create module in `modules/apps/module-name/`
2. Add to `clusters/modules.tf`, the idea is to keep DRY and modules there should be usable by all clusters:
   ```hcl
   module "module_name" {
     count  = contains(local.workload, "module_name") ? 1 : 0
     source = "../modules/apps/module-name"
   }
   ```
3. Add to workspace workload in `clusters/variables.tf` and it will instantiate the module into a cluster:
   ```hcl
   variable "workload" {
     default = {
       dev = ["existing", "module_name"]
     }
   }
   ```
4. Add env module config:
   ```hcl
   variable "config" {
     default = {
       dev = {
        module_name = {}
       }
     }
   }
   ```

### Adding a New Cluster (Cluster API - Recommended)

**For Talos Linux cluster:**

1. Add cluster config to `clusters/variables.tf` under tools (because tools cluster is the cluster-api management cluster) workspace:
   ```hcl
   config = {
     default = {
      tools = {
        proxmox-talos-cluster = [
          {
            name                      = "dev"
            kubernetes_version        = "v1.33.0"
            control_plane_endpoint_ip = "192.168.1.50"
            ip_range_start            = "192.168.1.51"
            ip_range_end              = "192.168.1.56"
            gateway                   = "192.168.1.1"
            prefix                    = 24
            dns_servers               = ["192.168.1.3", "8.8.4.4"]

            source_node   = "node03"
            template_id   = 9005
            allowed_nodes = ["node03"]

            cp_replicas = 1
            wk_replicas = 2

            cp_disk_size = 20
            cp_memory    = 4096
            cp_cores     = 4
            wk_disk_size = 30
            wk_memory    = 8192
            wk_cores     = 8
          },...]
     }
   }
   ```

3. Commit your changes and CI/CD does the rest

**For legacy K3s VM (deprecated approach):**

1. Create YAML in `proxmox/vms/vm-name.yaml`
2. Add Ansible playbook in `proxmox/playbooks/vm-name.yml`
3. Commit with `[ansible vm-name]` tag to trigger provisioning

### Adding a New Environment

1. Create OpenTofu workspace: `make create-workspace ENV=newenv`
2. Add to `clusters/variables.tf`:
   - Add to `workload` variable with module list
   - Add to `config` variable with environment settings
3. Update `Makefile` ENVIRONMENTS list if needed
4. Run `make plan ENV=newenv`

### Handling Secrets

**Never commit unencrypted secrets.** Always use SOPS:

```bash
# View secret
./secret_view.sh secrets/common/cluster-secret-store/secrets/TELEPORT_DB_CA.yaml

# New secret
./secret_new.sh secrets/path/to/secret.yaml
# Edit in $EDITOR, SOPS encrypts on save

# Reference in OpenTofu
cd clusters && python3 load_secrets.py
# Then access via local.secrets_json
```

### Istio Integration

Modules support both Istio and Traefik (k3s) ingress:

```hcl
use_istio = contains(local.workload, "istio")
ingress_class_name = use_istio ? "istio" : "traefik"
```

When Istio is enabled, modules should create:
- `VirtualService` instead of `Ingress`
- `Gateway` resources for TLS termination
- Additional DNS sources for external-dns

## OpenTofu State Management

**Backend:**
- S3-compatible (MinIO) at `s3.fullstack.pw`
- Defined in `clusters/backend.tf`
- Workspace-specific state files
- Automated daily backup to Oracle Cloud Object Storage

**State Operations:**
```bash
# Switch workspace
cd clusters && tofu workspace select dev

# List workspaces
make workspace

# Import existing resource
cd clusters
OpenTofu import 'module.postgres[0].module.helm.helm_release.this[0]' default/postgres
```

## Development Environment Setup

**Required Tools:**
- OpenTofu 1.10.5+ (or OpenTofu 1.9.0+ for migration)
- Ansible
- SOPS and age (installed via `make install-crypto-tools`)
- kubectl
- Python 3 with PyYAML
- Go 1.22+ (for cicd-update-kubeconfig)

**Environment Variables:**
```bash
export SOPS_AGE_KEY_FILE=~/.sops/keys/sops-key.txt
export VAULT_TOKEN=<vault-token>
export VAULT_ADDR=https://vault.fullstack.pw
export KUBECONFIG=~/.kube/config
export PROXMOX_PASSWORD=<proxmox-password>
```

## Troubleshooting Common Issues

**OpenTofu plan shows unwanted changes:**
- Check if `load_secrets.py` was run: `cd clusters && python3 load_secrets.py`
- Verify correct workspace: `OpenTofu workspace show`
- Check for state drift: Review recent OpenTofu operations

**Ansible playbook not triggering:**
- Verify commit message contains `[ansible playbook-name]`
- Check `.github/workflows/ansible.yml` for playbook existence
- Review GitHub Actions logs

**Module not deploying:**
- Verify module name in workspace's `workload` list in `variables.tf`
- Check module count condition: `count = contains(local.workload, "module_name") ? 1 : 0`
- Ensure workspace is selected: `OpenTofu workspace select <env>`

**Chicken-and-egg CRD issues:**
- Set `create_default_gateway = false` or `install_crd = false` initially
- Run `OpenTofu apply` to install CRDs
- Set flag to `true` and apply again

**Kubeconfig not in Vault (Cluster API clusters):**
- Verify cluster is ready: `kubectl --context <mgmt-context> get cluster -n <namespace> <cluster-name>`
- Check Cluster API secret exists: `kubectl --context <mgmt-context> get secret -n <namespace> <cluster>-kubeconfig`
- Check secret has `value` key: `kubectl --context <mgmt-context> get secret -n <namespace> <cluster>-kubeconfig -o jsonpath='{.data.value}' | base64 -d`
- Run manually: `./cicd-update-kubeconfig --cluster-name <cluster> --namespace <namespace> --vault-path kv/cluster-secret-store/secrets --vault-addr $VAULT_ADDR --management-context <mgmt-context>`
- Verify VAULT_TOKEN is valid and has write permissions
- Check CI/CD logs in `.github/workflows/OpenTofu-apply.yml` "Update Kubeconfigs in Vault" step

## Testing Changes

**Always test in this order:**
1. `make fmt` - Format code
2. `make validate` - Validate syntax
3. `make plan ENV=<test-env>` - Review planned changes
4. Review plan output carefully
5. `make apply ENV=<test-env>` - Apply to test environment
6. Verify deployment: `kubectl --context <test-env> get all -A`
7. Only then apply to production environments

## Physical Infrastructure Context

- 3 Proxmox nodes: NODE01 (i7-4710HQ, 16GB), NODE02 (i7-7700T, 32GB), NODE03 (dual Xeon E5-2699-V3, 128GB)
- **Management cluster**: `tools` (K3s on NODE02) - runs Cluster API operator
- **Legacy K3s clusters**: dev, stg, prod, tools, home, observability (single-node)
- **Cluster API clusters**: Deployed in `sandboxy` workspace (Talos/kubeadm multi-node)
- Network: 192.168.1.0/24
- DNS: Pi-hole (192.168.1.3) for internal, Cloudflare for public

## Current State & Migration Notes

**Active Provisioning Method:**
- New clusters: Cluster API (Talos/kubeadm) via OpenTofu modules
- Legacy clusters: K3s via Proxmox OpenTofu + Ansible (dev/stg/prod/tools/home/observability)

**Deprecated but Still Present:**
- `proxmox/` OpenTofu for VM provisioning (commented out in OpenTofu-apply.yml)
- `[ansible PLAYBOOK]` commit tag pattern (still works for K3s maintenance)
- Individual VM YAML definitions in `proxmox/vms/`

**In Validation:**
- Kubeconfig update automation in `.github/workflows/OpenTofu.yml`
- Automatic detection of cluster changes (CREATE/UPDATE/DELETE)
- Retry logic for cluster readiness (3 attempts, 30s intervals)
- `continue-on-error: true` for kubeconfig updates (workflow doesn't fail, posts warning comment)

## References

- README.md - Comprehensive architecture documentation
- docs/SECRETS_ROTATION.md - Secret rotation procedures
- docs/ISTIO.md - Istio migration guide
- cicd-update-kubeconfig/README.md - Kubeconfig management tool docs
