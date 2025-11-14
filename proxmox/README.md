# Proxmox Infrastructure Automation

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [VM Bootstrap Procedure](#vm-bootstrap-procedure)
4. [Architecture & Components](#architecture--components)
5. [Technical Reference](#technical-reference)
6. [Troubleshooting](#troubleshooting)

---

## Overview

This directory contains the automated VM provisioning infrastructure for Proxmox, utilizing a GitOps workflow that chains Terraform and Ansible together to create and configure VMs with minimal manual intervention.

### Key Features

- **Single-commit VM creation**: Define a VM in YAML and commit with an ansible tag to automatically create and provision it
- **Automated configuration**: Ansible playbooks run automatically after VM creation
- **Kubernetes integration**: K8s clusters are automatically added to CI/CD kubeconfig via Vault
- **GitOps workflow**: Everything is version-controlled and automated via GitHub Actions
- **Zero manual intervention**: From VM definition to running workloads, the entire process is automated

### How It Works

The automation uses a special commit message tag `[ansible PLAYBOOK_NAME]` that chains multiple workflows together:

1. Terraform creates the VM in Proxmox
2. Inventory is automatically updated with the new VM details
3. The ansible tag is preserved in an automated commit
4. Ansible workflow triggers and provisions the new VM
5. For K8s VMs, the cluster is added to Vault kubeconfig for CI/CD access

---

## Prerequisites

### Required GitHub Secrets

- `PROXMOX_*` - Proxmox API credentials
- `VAULT_TOKEN` - Vault authentication token
- `VAULT_ADDR` - Vault server URL (e.g., `https://vault.fullstack.pw`)
- `SSH_PRIVATE_KEY` - SSH key for Ansible connections

### Required Infrastructure

- Proxmox cluster with API access
- HashiCorp Vault instance for secret management
- VM templates available in Proxmox:
  - `ubuntu24-template` (or your preferred base image)
- GitHub Actions runners with network access to Proxmox

### Vault Configuration

The kubeconfig for all K8s clusters is stored at:
```
kv/cluster-secret-store/secrets/KUBECONFIG
```

This allows CI/CD workflows to access any provisioned Kubernetes cluster.

---

## VM Bootstrap Procedure

This is the complete procedure for creating and provisioning a new VM, from initial definition to workload deployment.

### Step 1: Create VM Definition

Create a new YAML file in `proxmox/vms/` with your VM configuration.

**File:** `proxmox/vms/k8s-observability.yaml`

```yaml
name: k8s-observability
target_node: node03
cores: 4
sockets: 2
memory: 16384
cpu_type: host
clone: ubuntu24-template
ipconfig0: "ip=192.168.1.20/24,gw=192.168.1.1,ip6=dhcp"
ciuser: suporte
network:
  bridge: vmbr0
  model: virtio
disks:
  scsi0:
    size: 50G
    storage: local-lvm
  scsi1:
    size: 200G
    storage: local-lvm
    mount: /mnt/storage
```

#### VM Naming Conventions

VM names determine their inventory categorization:

| Pattern | Inventory Group | Playbook Usage |
|---------|----------------|----------------|
| `k8s-*` | `[k3s]` | K3s single-node cluster installation |
| `haproxy-*` | `[haproxy]` | HAProxy load balancer configuration |
| `talos-*-cp*` | `[talos_control_plane]` | Talos control plane nodes |
| `talos-*-w*` | `[talos_workers]` | Talos worker nodes |

#### Required Fields

- `name` - VM hostname (must be unique)
- `target_node` - Proxmox node to create VM on
- `cores` - CPU cores
- `memory` - RAM in MB
- `clone` - Template to clone from
- `ipconfig0` - Network configuration with static IP
- `ciuser` - Default user for cloud-init

#### Optional Fields

- `sockets` - CPU sockets (default: 1)
- `cpu_type` - CPU type (default: host)
- `network` - Network interface configuration
- `disks` - Additional disk configuration

### Step 2: Commit with Ansible Tag

Create a commit with the special `[ansible PLAYBOOK_NAME]` tag in the commit message:

```bash
git add proxmox/vms/k8s-observability.yaml
git commit -m "feat(proxmox): add k8s-observability VM [ansible k8s-observability]"
git push origin feature/add-observability-cluster
```

#### Commit Message Format

```
<type>(<scope>): <description> [ansible PLAYBOOK_NAME]
```

**Important:** The `[ansible PLAYBOOK_NAME]` tag is **CRITICAL** - it triggers the entire automated provisioning chain.

#### Playbook Name Rules

For **K8s VMs** (pattern `k8s-*`):
- Use the VM name as the playbook name
- Example: VM `k8s-observability` → tag `[ansible k8s-observability]`
- This will execute `proxmox/playbooks/k8s.yml` with the VM as target

For **other VM types**:
- Use the playbook name without `.yml` extension
- Example: HAProxy VM → tag `[ansible haproxy]`
- This will execute `proxmox/playbooks/haproxy.yml`

#### Examples

```bash
# K8s single-node cluster
"feat(proxmox): add k8s-dev VM [ansible k8s-dev]"

# HAProxy load balancer
"feat(proxmox): add haproxy-prod VM [ansible haproxy]"

# Talos control plane node
"feat(proxmox): add talos-prod-cp01 VM [ansible talos]"
```

### Step 3: Automated Pipeline Flow

After your PR is merged to main, the following automated sequence occurs:

#### 3.1 Release Workflow

**Workflow:** [`.github/workflows/release.yml`](../.github/workflows/release.yml)

- Runs semantic-release for versioning
- Creates changelog entries
- Must complete before Terraform proceeds

#### 3.2 Terraform Apply

**Workflow:** [`.github/workflows/terraform-apply.yml`](../.github/workflows/terraform-apply.yml)

**What happens:**

1. **Wait for Release** (Lines 18-72)
   - Polls GitHub API for up to 300 seconds
   - Ensures release workflow completes first

2. **Apply Terraform** (Lines 93-131)
   - Working directory: `./proxmox`
   - Reads all `*.yaml` files from `proxmox/vms/` (excluding `k8s-home.yaml` and `boot-server.yaml`)
   - Creates VM in Proxmox using `proxmox_vm_qemu` resource
   - See [`proxmox/main.tf`](main.tf) for implementation details

3. **Extract Ansible Tag** (Lines 132-148)
   ```bash
   # Line 139 - This is the tag extraction logic
   if [[ $COMMIT_MSG =~ \[ansible[[:space:]]+([^\]]+)\] ]]; then
     PLAYBOOK="${BASH_REMATCH[1]}"
     echo "ANSIBLE_TAG=[ansible $PLAYBOOK]" >> $GITHUB_ENV
   fi
   ```

4. **Update Ansible Inventory** (Lines 157-163)
   - Executes [`proxmox/update-inventory.sh`](update-inventory.sh)
   - **Line 24 of script:** Reads Terraform outputs
     ```bash
     terraform output -json > ../tf_output.json
     ```
   - Parses VM information (IPs, hostnames)
   - Updates [`proxmox/k8s.ini`](k8s.ini) with new VM
   - Creates [`proxmox/new_hosts.txt`](new_hosts.txt) with format: `IP,hostname`
   - Categorizes VMs into inventory groups based on naming patterns

5. **Commit Inventory Changes** (Lines 165-195)
   - Commits `proxmox/k8s.ini` and `proxmox/new_hosts.txt`
   - **Preserves the ansible tag** in the commit message:
     ```
     Auto-update Ansible inventory [ansible k8s-observability]
     ```
   - Pushes to main branch

#### 3.3 Ansible Provisioning

**Workflow:** [`.github/workflows/ansible.yml`](../.github/workflows/ansible.yml)

**Triggers:** Push to main containing `[ansible` in commit message

**What happens:**

1. **Parse Commit Message** (Lines 29-30)
   ```bash
   if [[ $COMBINED =~ \[ansible[[:space:]]+([^\]]+)\] ]]; then
     PLAYBOOK="${BASH_REMATCH[1]}"
   fi
   ```

2. **Determine Playbook** (Lines 53-80)
   - **K3s Pattern** (Lines 59-64): If playbook matches `k8s-*`, uses `proxmox/playbooks/k8s.yml`
   - **Direct Playbook** (Lines 66-77): Uses `proxmox/playbooks/${PLAYBOOK}.yml`

3. **Prepare SSH** (Lines 119-141)
   - Reads `new_hosts.txt` to get new VM IPs
   - Scans SSH host keys
   - Adds to `known_hosts`

4. **Execute Playbook** (Lines 143-188)

   **For K3s clusters:**
   ```bash
   ansible-playbook proxmox/playbooks/k8s.yml \
     -i proxmox/k8s.ini \
     -e "target_hosts=k8s-observability" \
     -e "vault_token=${VAULT_TOKEN}" \
     -e "vault_addr=https://vault.fullstack.pw"
   ```

   **For other playbooks:**
   - Creates temporary inventory for each new host
   - Runs playbook only against new VMs from `new_hosts.txt`

#### 3.4 Kubernetes Cluster Setup (K3s Playbook)

**Playbook:** [`proxmox/playbooks/k8s.yml`](playbooks/k8s.yml)

For K8s VMs, the playbook performs the following:

1. **Install K3s** (Lines 64-70)
   ```bash
   curl -sfL https://get.k3s.io | \
     INSTALL_K3S_EXEC="--default-local-storage-path=/mnt/storage" sh -s -
   ```

2. **Fetch Kubeconfig** (Lines 111-114)
   - Reads `/etc/rancher/k3s/k3s.yaml`
   - Replaces `127.0.0.1` with actual host IP
   - Updates context name to match VM hostname

3. **Update Vault Kubeconfig** (Lines 160-174)
   - Uses [`proxmox/scripts/update_kubeconfig.py`](scripts/update_kubeconfig.py)
   - Reads existing kubeconfig from Vault path: `kv/cluster-secret-store/secrets/KUBECONFIG`
   - Merges new cluster configuration:
     - **Context name:** VM hostname (e.g., `k8s-observability`)
     - **Cluster/User name:** Generated name (e.g., `cozy-haven`)
   - Writes updated kubeconfig back to Vault
   - **Result:** CI/CD pipelines can now access this cluster

### Step 4: Deploy Workloads (K8s Clusters Only)

After the K8s cluster is provisioned and added to Vault, you can deploy workloads using the clusters Terraform.

#### 4.1 Add Cluster Configuration

**File:** `clusters/variables.tf`

Add your cluster workspace configuration:

```hcl
# Workspace definition (Lines 58-63)
observability = [
  "externaldns",
  "cert_manager",
  "external_secrets",
  "observability"
]

# Cluster context (Lines 140-144)
observability = {
  kubernetes_context = "k8s-observability"
  install_crd        = true
  cert_manager_crd   = true
}
```

#### 4.2 Commit and Apply

```bash
cd clusters/
terraform workspace select observability  # or create if new
terraform plan
```

Then commit your changes:

```bash
git add clusters/variables.tf
git commit -m "feat(clusters): add observability cluster workloads"
git push origin feature/observability-workloads
```

After merge, the `terraform-apply` workflow will:
- Switch to the `observability` workspace
- Use context `k8s-observability` from Vault kubeconfig
- Install the specified workloads (ExternalDNS, CertManager, ExternalSecrets, Observability stack)

#### 4.3 Available Workloads

See [`clusters/modules.tf`](../clusters/modules.tf) for available workload modules:

- **external-dns** - Cloudflare and Pi-hole DNS integration
- **cert_manager** - Let's Encrypt certificate management
- **external_secrets** - Vault secrets integration
- **observability** - Prometheus, Grafana, Loki stack
- **argocd** - GitOps continuous delivery
- **istio** - Service mesh
- And more...

---

## Architecture & Components

### Terraform Components

#### [`proxmox/main.tf`](main.tf)

**Lines 1-4:** Reads all VM YAML definitions
```hcl
data "local_file" "yaml_files" {
  for_each = setsubtract(fileset("${path.module}/vms", "*.yaml"),
                         ["k8s-home.yaml", "boot-server.yaml"])
  filename = "${path.module}/vms/${each.key}"
}
```

**Lines 6-11:** Parses YAML into Terraform configs
```hcl
locals {
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
}
```

**Lines 13-153:** Creates VMs using `proxmox_vm_qemu` resource

#### [`proxmox/outputs.tf`](outputs.tf)

Defines outputs for Ansible inventory:
- `vm_ips` - All VM IPs mapped by name
- `k8s_nodes` - K8s-specific node details
- `ansible_inventory` - Structured inventory data

### Ansible Components

#### [`proxmox/k8s.ini`](k8s.ini)

Ansible inventory file with groups:
- `[haproxy]` - HAProxy VMs
- `[talos_control_plane]` - Talos control plane nodes
- `[talos_workers]` - Talos worker nodes
- `[k3s]` - K3s cluster VMs
- `# Individual hosts` - All VMs with their IPs

#### [`proxmox/new_hosts.txt`](new_hosts.txt)

Tracks newly created VMs in format: `192.168.1.20,k8s-observability`

Used by Ansible workflow to:
- Scan SSH host keys
- Limit playbook execution to only new VMs

#### [`proxmox/update-inventory.sh`](update-inventory.sh)

Automation script that:

1. **Line 24:** Reads Terraform outputs
   ```bash
   terraform output -json > ../tf_output.json
   ```

2. **Lines 28-72:** Parses VM data from outputs

3. **Lines 74-80:** Detects new VMs (not in current inventory)

4. **Lines 269-318:** Updates `k8s.ini`:
   - Adds new hosts under "# Individual hosts" section
   - Categorizes by naming pattern:
     - `haproxy-*` → `[haproxy]`
     - `talos-*-cp*` → `[talos_control_plane]`
     - `talos-*-w*` → `[talos_workers]`
     - `k8s-*` → `[k3s]`

5. **Line 294:** Writes new VMs to `new_hosts.txt`

6. **Lines 326-351:** Validates inventory syntax

#### [`proxmox/playbooks/`](playbooks/)

Ansible playbooks for VM provisioning:
- `k8s.yml` - K3s single-node cluster installation
- `haproxy.yml` - HAProxy load balancer setup
- `talos.yml` - Talos Linux cluster setup
- And more...

#### [`proxmox/scripts/update_kubeconfig.py`](scripts/update_kubeconfig.py)

Python script for Vault kubeconfig management:

**Lines 94-147:** Merge logic
- Reads existing kubeconfig from Vault
- Updates cluster/user names to use generated cluster name
- Updates context name to use VM hostname (e.g., `k8s-observability`)
- Merges into existing kubeconfig (preserves other clusters)
- Writes back to Vault

This ensures stable context names for CI/CD while allowing flexible cluster naming.

### GitHub Workflows

#### [`.github/workflows/terraform-apply.yml`](../.github/workflows/terraform-apply.yml)

Orchestrates VM creation and inventory updates.

**Key sections:**
- **Lines 18-72:** Wait for release workflow
- **Lines 74-91:** Detect changes to `proxmox/**` or `clusters/**`
- **Lines 93-131:** Apply Proxmox Terraform
- **Lines 132-148:** Extract ansible tag from commit (Line 139 is the regex)
- **Lines 157-163:** Run inventory update script
- **Lines 165-195:** Commit changes with preserved tag
- **Lines 197-258:** Apply clusters Terraform (workload deployment)

#### [`.github/workflows/ansible.yml`](../.github/workflows/ansible.yml)

Provisions VMs using Ansible playbooks.

**Key sections:**
- **Lines 8-10:** Trigger on `[ansible` in commit message
- **Lines 29-30:** Parse playbook name from commit
- **Lines 53-80:** Determine playbook path (k8s.yml for k8s-* pattern)
- **Lines 81-117:** Validate inventory
- **Lines 119-141:** Prepare SSH keys
- **Lines 143-188:** Execute playbook

#### [`.github/workflows/release.yml`](../.github/workflows/release.yml)

Semantic versioning and changelog generation.

---

## Technical Reference

### The Two-Step Commit Mechanism

**Why does the pipeline commit twice?**

The automation faces a timing challenge:

1. **First commit:** Developer commits VM definition with `[ansible k8s-observability]` tag
   - Terraform applies and creates VM
   - **Problem:** VM doesn't exist yet, so Ansible can't run

2. **Second commit:** Pipeline commits inventory updates with preserved tag
   - Now VM exists in Proxmox
   - Ansible can SSH to the new VM and provision it

**Solution:** `new_hosts.txt`
- Written by `update-inventory.sh` after Terraform creates VM
- Contains newly created VMs that need provisioning
- Read by Ansible workflow to limit execution to only new hosts
- Prevents re-provisioning existing VMs

### Ansible Tag Preservation Flow

```
1. Developer commits:
   "feat(proxmox): add k8s-observability VM [ansible k8s-observability]"

2. Terraform Apply workflow:
   - Line 136: COMMIT_MSG=$(git log -1 --pretty=format:"%s")
   - Line 139: Regex extracts "k8s-observability" from [ansible k8s-observability]
   - Line 140: ANSIBLE_TAG="[ansible k8s-observability]"

3. Inventory commit (Lines 185-189):
   if [ -n "$ANSIBLE_TAG" ]; then
     COMMIT_MSG="Auto-update Ansible inventory $ANSIBLE_TAG"
   fi

   Result: "Auto-update Ansible inventory [ansible k8s-observability]"

4. Ansible workflow triggers:
   - Line 10: on.push.paths includes "proxmox/new_hosts.txt"
   - Line 29-30: Parses commit message, extracts playbook name
   - Runs playbook against new VM
```

### Inventory Categorization Rules

| VM Name Pattern | Added to Group | Example |
|----------------|----------------|---------|
| `haproxy-prod` | `[haproxy]` | HAProxy load balancers |
| `k8s-observability` | `[k3s]` | K3s single-node clusters |
| `talos-prod-cp01` | `[talos_control_plane]` | Talos control plane |
| `talos-prod-w01` | `[talos_workers]` | Talos worker nodes |
| Other names | Individual hosts only | Special-purpose VMs |

**Implementation:** [`update-inventory.sh` Lines 298-303](update-inventory.sh)

### Kubeconfig Context Naming

For K8s clusters provisioned by `k8s.yml` playbook:

- **Context name:** VM hostname (e.g., `k8s-observability`)
  - Stable, predictable name for CI/CD
  - Matches Terraform `kubernetes_context` variable

- **Cluster/User name:** Generated random name (e.g., `cozy-haven`)
  - Unique identifier for the cluster
  - Can be renamed without breaking CI/CD

**Why this matters:**
- Terraform in `clusters/` uses `kubernetes_context = "k8s-observability"`
- This context name must be stable and predictable
- The actual cluster name can vary

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Developer Creates VM Definition                         │
│ File: proxmox/vms/k8s-observability.yaml                        │
│ Commit: "feat(proxmox): add k8s-observability VM                │
│          [ansible k8s-observability]"                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ PR merged to main
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Release Workflow                                        │
│ Workflow: .github/workflows/release.yml                         │
│ - Semantic versioning                                           │
│ - Changelog generation                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Terraform Apply Workflow                                │
│ Workflow: .github/workflows/terraform-apply.yml                 │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 3.1: Apply Terraform (Lines 93-131)                      │   │
│ │ - Reads proxmox/vms/*.yaml                               │   │
│ │ - Creates VM in Proxmox                                  │   │
│ │ - VM now exists at 192.168.1.20                          │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 3.2: Extract Ansible Tag (Lines 132-148)                 │   │
│ │ - Line 139: Regex extracts "k8s-observability"           │   │
│ │ - ANSIBLE_TAG="[ansible k8s-observability]"              │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 3.3: Update Inventory (Lines 157-163)                    │   │
│ │ Script: proxmox/update-inventory.sh                      │   │
│ │                                                           │   │
│ │ - Line 24: terraform output -json                        │   │
│ │ - Detects new VM: k8s-observability (192.168.1.20)       │   │
│ │ - Updates proxmox/k8s.ini (adds to [k3s] group)          │   │
│ │ - Writes proxmox/new_hosts.txt:                          │   │
│ │   "192.168.1.20,k8s-observability"                       │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 3.4: Commit Changes (Lines 165-195)                      │   │
│ │ Files: proxmox/k8s.ini, proxmox/new_hosts.txt            │   │
│ │ Message: "Auto-update Ansible inventory                  │   │
│ │           [ansible k8s-observability]"                   │   │
│ │ *** TAG PRESERVED ***                                    │   │
│ └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Push to main (with ansible tag)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Ansible Workflow                                        │
│ Workflow: .github/workflows/ansible.yml                         │
│ Trigger: Commit contains "[ansible"                             │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 4.1: Parse Commit (Lines 29-30)                          │   │
│ │ - Extracts: playbook="k8s-observability"                 │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 4.2: Determine Playbook (Lines 59-64)                    │   │
│ │ - Pattern matches "k8s-*"                                │   │
│ │ - Uses: proxmox/playbooks/k8s.yml                        │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 4.3: Prepare SSH (Lines 119-141)                         │   │
│ │ - Reads new_hosts.txt                                    │   │
│ │ - Scans 192.168.1.20 for host keys                       │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 4.4: Execute Playbook (Lines 153-157)                    │   │
│ │ Command:                                                 │   │
│ │   ansible-playbook proxmox/playbooks/k8s.yml \           │   │
│ │     -i proxmox/k8s.ini \                                 │   │
│ │     -e "target_hosts=k8s-observability"                  │   │
│ └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: K3s Playbook Execution                                  │
│ Playbook: proxmox/playbooks/k8s.yml                             │
│                                                                  │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 5.1: Install K3s (Lines 64-70)                           │   │
│ │ - curl -sfL https://get.k3s.io | sh -s -                 │   │
│ │ - K3s cluster now running                                │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 5.2: Fetch Kubeconfig (Lines 111-114)                    │   │
│ │ - Reads /etc/rancher/k3s/k3s.yaml                        │   │
│ │ - Replaces 127.0.0.1 with 192.168.1.20                   │   │
│ │ - Updates context name to "k8s-observability"            │   │
│ └──────────────────────────────────────────────────────────┘   │
│                         │                                        │
│ ┌──────────────────────────────────────────────────────────┐   │
│ │ 5.3: Update Vault (Lines 160-174)                        │   │
│ │ Script: proxmox/scripts/update_kubeconfig.py             │   │
│ │                                                           │   │
│ │ - Reads from Vault:                                      │   │
│ │   kv/cluster-secret-store/secrets/KUBECONFIG             │   │
│ │ - Merges new cluster config:                             │   │
│ │   * Context: k8s-observability                           │   │
│ │   * Cluster: cozy-haven (or other generated name)        │   │
│ │ - Writes back to Vault                                   │   │
│ │                                                           │   │
│ │ ✓ CI/CD can now access this cluster                      │   │
│ └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Cluster ready for workloads
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6: Deploy Workloads (Manual)                               │
│                                                                  │
│ Developer commits to clusters/ folder:                          │
│ - Adds workspace "observability" to variables.tf                │
│ - Sets kubernetes_context = "k8s-observability"                 │
│ - Defines workloads: externaldns, cert_manager, etc.            │
│                                                                  │
│ After merge:                                                    │
│ - Terraform Apply workflow (Lines 197-258)                      │
│ - Uses kubeconfig from Vault                                    │
│ - Connects to context "k8s-observability"                       │
│ - Installs specified workloads                                  │
│                                                                  │
│ ✓ VM is now fully operational with workloads                    │
└─────────────────────────────────────────────────────────────────┘
```

### Key File Reference

| File | Purpose | Critical Lines |
|------|---------|----------------|
| `.github/workflows/terraform-apply.yml` | VM creation orchestration | 139 (tag extraction), 162 (inventory update) |
| `.github/workflows/ansible.yml` | VM provisioning | 29-30 (commit parsing), 153-157 (playbook execution) |
| `proxmox/update-inventory.sh` | Inventory automation | 24 (terraform output), 294 (new_hosts.txt) |
| `proxmox/main.tf` | VM resource definitions | 1-11 (YAML parsing), 13-153 (VM creation) |
| `proxmox/outputs.tf` | Terraform outputs | 4-10 (vm_ips), 13-22 (k8s_nodes) |
| `proxmox/k8s.ini` | Ansible inventory | All - host and group definitions |
| `proxmox/new_hosts.txt` | New VM tracker | All - IP,hostname format |
| `proxmox/playbooks/k8s.yml` | K3s installation | 64-70 (install), 160-174 (Vault update) |
| `proxmox/scripts/update_kubeconfig.py` | Vault kubeconfig merger | 94-147 (merge logic) |
| `clusters/variables.tf` | Cluster workload config | 58-63 (workloads), 140-144 (context) |
| `clusters/modules.tf` | Workload modules | 149-155 (observability module) |

---

## Troubleshooting

### VM Created but Ansible Didn't Run

**Symptoms:**
- VM exists in Proxmox
- `k8s.ini` was updated
- `new_hosts.txt` was created
- But Ansible workflow didn't trigger

**Check:**
1. Verify the automated commit has the ansible tag:
   ```bash
   git log -1 --oneline
   # Should show: Auto-update Ansible inventory [ansible PLAYBOOK_NAME]
   ```

2. Check if `new_hosts.txt` was committed:
   ```bash
   git log -1 --stat
   # Should include: proxmox/new_hosts.txt
   ```

3. Check Ansible workflow runs:
   ```bash
   gh run list --workflow=ansible.yml
   ```

**Solution:**
If the tag was lost, manually trigger the playbook:
```bash
cd proxmox
ansible-playbook playbooks/k8s.yml \
  -i k8s.ini \
  -e "target_hosts=k8s-observability"
```

### Ansible Playbook Failed

**Symptoms:**
- Ansible workflow ran but failed
- VM exists but isn't configured

**Common Issues:**

1. **SSH Connection Failed**
   - Check VM is reachable: `ping 192.168.1.20`
   - Verify SSH key is correct in GitHub secrets
   - Check cloud-init completed: `ssh user@192.168.1.20 'cloud-init status'`

2. **Playbook Syntax Error**
   - Validate locally: `ansible-playbook playbooks/k8s.yml --syntax-check`
   - Check for YAML indentation issues

3. **Vault Connection Failed**
   - Verify `VAULT_TOKEN` secret is valid
   - Check Vault is reachable from GitHub runners
   - Test manually: `vault status`

**Solution:**
Re-run the Ansible workflow manually from GitHub Actions UI, or run locally:
```bash
cd proxmox
ansible-playbook playbooks/k8s.yml \
  -i k8s.ini \
  -e "target_hosts=k8s-observability" \
  -e "vault_token=$VAULT_TOKEN" \
  -e "vault_addr=https://vault.fullstack.pw" \
  -vvv  # Verbose output
```

### Terraform Apply Failed

**Symptoms:**
- Terraform workflow failed
- VM not created

**Common Issues:**

1. **Proxmox API Error**
   - Check Proxmox credentials in GitHub secrets
   - Verify target node has resources available
   - Check template exists: `clone: ubuntu24-template`

2. **IP Already in Use**
   - Check for IP conflicts in your network
   - Verify IP isn't already assigned in Proxmox

3. **YAML Syntax Error**
   - Validate locally: `yamllint vms/k8s-observability.yaml`
   - Check for indentation issues

**Solution:**
Fix the issue and re-run Terraform:
```bash
cd proxmox
terraform plan
terraform apply
```

Or trigger the workflow manually from GitHub Actions UI.

### Kubeconfig Not in Vault

**Symptoms:**
- K3s installed successfully
- But kubeconfig not in Vault
- Clusters Terraform can't connect

**Check:**
1. Verify Vault token has write permissions:
   ```bash
   vault kv get kv/cluster-secret-store/secrets/KUBECONFIG
   ```

2. Check the `update_kubeconfig.py` script logs in Ansible workflow output

**Solution:**
Manually run the kubeconfig update:
```bash
cd proxmox

# Fetch kubeconfig from K3s node
ssh user@192.168.1.20 'sudo cat /etc/rancher/k3s/k3s.yaml' > temp-kubeconfig.yaml

# Update Vault using the script
python3 scripts/update_kubeconfig.py \
  --kubeconfig temp-kubeconfig.yaml \
  --cluster-name k8s-observability \
  --inventory-name k8s-observability \
  --vault-token $VAULT_TOKEN \
  --vault-addr https://vault.fullstack.pw
```

### Workload Deployment Failed

**Symptoms:**
- Terraform in `clusters/` failed
- Kubernetes context not found

**Check:**
1. Verify kubeconfig in Vault has the context:
   ```bash
   vault kv get -field=KUBECONFIG kv/cluster-secret-store/secrets/KUBECONFIG | \
     yq '.contexts[].name'
   # Should include: k8s-observability
   ```

2. Verify `kubernetes_context` in `clusters/variables.tf` matches:
   ```hcl
   observability = {
     kubernetes_context = "k8s-observability"  # Must match exactly
     ...
   }
   ```

**Solution:**
1. Fix the context name mismatch
2. Or update the context name in Vault kubeconfig
3. Re-run clusters Terraform

### Inventory Validation Failed

**Symptoms:**
- `update-inventory.sh` failed
- Backup file `k8s.ini.bak` exists
- Inventory not updated

**Check:**
```bash
cd proxmox
ansible-inventory -i k8s.ini --list
```

**Common Issues:**
- Duplicate host definitions
- Invalid YAML/INI syntax
- Circular group dependencies

**Solution:**
1. Restore from backup if needed:
   ```bash
   cp k8s.ini.bak k8s.ini
   ```

2. Manually fix the inventory

3. Validate:
   ```bash
   ansible-inventory -i k8s.ini --list
   ```

### General Debugging Tips

1. **Check workflow logs:**
   ```bash
   gh run list
   gh run view <run-id> --log
   ```

2. **Verify secrets are set:**
   ```bash
   gh secret list
   ```

3. **Test Terraform locally:**
   ```bash
   cd proxmox
   terraform init
   terraform plan
   ```

4. **Test Ansible locally:**
   ```bash
   cd proxmox
   ansible -i k8s.ini k8s-observability -m ping
   ```

5. **Check VM status in Proxmox:**
   - Web UI: https://your-proxmox:8006
   - Or via CLI: `pvesh get /cluster/resources --type vm`

---

## Advanced Topics

### Custom Playbooks

To create a custom playbook for a specific VM type:

1. **Create playbook:** `proxmox/playbooks/myapp.yml`

2. **Add tasks:**
   ```yaml
   - hosts: "{{ target_hosts | default('all') }}"
     become: yes
     tasks:
       - name: Install my application
         apt:
           name: myapp
           state: present
   ```

3. **Commit VM with tag:**
   ```bash
   git commit -m "feat(proxmox): add myapp VM [ansible myapp]"
   ```

4. **Playbook will run automatically** after VM creation

### Multi-Node Clusters

For multi-node K8s clusters (not single-node K3s):

1. **Create multiple VMs** with appropriate names:
   - `k8s-prod-cp01`, `k8s-prod-cp02`, `k8s-prod-cp03` (control plane)
   - `k8s-prod-w01`, `k8s-prod-w02` (workers)

2. **Use a different playbook** (not `k8s.yml`):
   - Create `proxmox/playbooks/k8s-ha.yml` for HA cluster setup

3. **Commit with custom tag:**
   ```bash
   git commit -m "feat(proxmox): add k8s-prod control plane [ansible k8s-ha]"
   ```

### Talos Clusters

For Talos Linux clusters:

1. **Create VMs with naming pattern:**
   - `talos-prod-cp01`, `talos-prod-cp02`, `talos-prod-cp03`
   - `talos-prod-w01`, `talos-prod-w02`, `talos-prod-w03`

2. **Use Talos playbook:**
   ```bash
   git commit -m "feat(proxmox): add Talos prod cluster [ansible talos]"
   ```

3. **Playbook will:**
   - Install Talos on all nodes
   - Bootstrap control plane
   - Join workers
   - Fetch kubeconfig to Vault

### Excluded VMs

Some VMs are excluded from Terraform automation (see [`proxmox/main.tf` Line 2](main.tf)):

- `k8s-home.yaml` - Manually managed home cluster
- `boot-server.yaml` - Special boot/PXE server

These VMs exist as YAML definitions but are not created by Terraform. They may be:
- Managed by a different process
- Created manually in Proxmox
- Templates for other VMs

To exclude a VM from automation, add it to the `setsubtract()` list in `main.tf`.

---

## Summary

This automated infrastructure allows you to:

1. **Define a VM in YAML** - Simple, declarative configuration
2. **Commit with an ansible tag** - One commit triggers the entire chain
3. **Wait for automation** - Terraform creates, Ansible provisions
4. **Deploy workloads** - Use clusters Terraform for K8s workloads

The entire process is:
- **GitOps-driven** - Everything in version control
- **Fully automated** - No manual steps required
- **Auditable** - All changes tracked in git history
- **Repeatable** - Same process for every VM

The `[ansible PLAYBOOK_NAME]` tag is the key mechanism that chains Terraform and Ansible together, enabling seamless VM lifecycle management from creation to production workloads.
