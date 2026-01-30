# Ephemeral PR-Based Kubernetes Clusters

Automatically provision ephemeral K3s clusters for pull requests, run tests, and destroy them when PRs close.

## Overview

This system creates isolated, short-lived Kubernetes clusters for each PR opened in application repositories (demo-apps, cks-backend, cks-frontend). Each cluster:

- Gets a unique DNS name: `pr-<pr-number>-<repo>.ephemeral.fullstack.pw`
- Has dedicated IP from pool: 192.168.1.140-149 (10 concurrent clusters max)
- Runs full regression tests before merging
- Auto-destroys after PR close (1 hour grace period) or after 3 days

## Architecture

```
PR Opened → Allocate IP → Provision K3s via Cluster API → Install Operators (Phase 1) →
Install Resources (Phase 2) → Deploy App → Run Tests → Post Results → [Keep Alive] →
PR Closed → Wait 1h → Destroy Cluster → Release IP
```

**Total Time**: ~7 minutes from PR open to tests starting

## Directory Structure

```
ephemeral-clusters/
├── README.md                           # This file
├── cluster-api/
│   └── k3s-cluster.yaml.tpl            # Cluster API manifest template
├── phase1-operators/
│   ├── README.md                       # Operator installation guide
│   ├── external-dns-cloudflare.yaml    # TODO: External-DNS (Cloudflare)
│   ├── external-dns-pihole.yaml        # TODO: External-DNS (Pi-hole)
│   ├── cert-manager.yaml               # TODO: Cert-Manager
│   └── external-secrets.yaml           # TODO: External-Secrets
└── phase2-resources/
    ├── README.md                       # Resource templates guide
    ├── clusterissuer.yaml              # Let's Encrypt ClusterIssuer
    ├── dnsendpoint.yaml.tpl            # DNS record template
    └── externalsecret.yaml.tpl         # Vault secret sync template
```

## Components

### 1. IP Pool Manager

**Location**: `/home/pedro/repos/infra/clusters/scripts/ip_pool_manager.sh`

Manages IP allocation from 192.168.1.140-149 using Vault for state tracking with CAS (Check-And-Set) for concurrency safety.

**Usage**:
```bash
# Allocate IP
export VAULT_ADDR=https://vault.fullstack.pw
export VAULT_TOKEN=<token>
./clusters/scripts/ip_pool_manager.sh allocate pr-cksbackend-42
# Returns: 192.168.1.140

# Release IP
./clusters/scripts/ip_pool_manager.sh release pr-cksbackend-42

# List allocations
./clusters/scripts/ip_pool_manager.sh list

# Check capacity
./clusters/scripts/ip_pool_manager.sh check-capacity
```

### 2. Cluster API Manifest Template

**Location**: `ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl`

Creates K3s single-node cluster via Cluster API on tools cluster:
- 1 control plane server (4 CPU, 8GB RAM, 20GB disk)
- K3s v1.30.6 with Traefik, local-path-provisioner, servicelb pre-installed
- kube-vip for control plane HA (single-node still uses VIP for consistency)

**Rendering**:
```bash
export CLUSTER_NAME=pr-cksbackend-42
export CLUSTER_IP=192.168.1.140
export PR_NUMBER=42
export REPOSITORY=cks-backend
envsubst < cluster-api/k3s-cluster.yaml.tpl > /tmp/cluster.yaml
kubectl apply -f /tmp/cluster.yaml --context tools
```

### 3. Phase 1: CRD Operators

**Location**: `ephemeral-clusters/phase1-operators/`

Installs operators that provide CRDs needed by Phase 2:
- **cert-manager**: For TLS certificates
- **external-dns**: For automatic DNS record management (Cloudflare + Pi-hole)
- **external-secrets**: For syncing secrets from Vault

**Installation**:
```bash
kubectl apply -f phase1-operators/ --kubeconfig <ephemeral-kubeconfig>

# Wait for CRDs
kubectl wait --for condition=established --timeout=3m \
  crd/certificates.cert-manager.io \
  crd/dnsendpoints.externaldns.k8s.io \
  crd/secretstores.external-secrets.io
```

**Status**: ✅ Complete - Manifests ready for deployment

### 4. Phase 2: CRD-Dependent Resources

**Location**: `ephemeral-clusters/phase2-resources/`

Creates resources using CRDs from Phase 1:
- **ClusterIssuer**: Let's Encrypt staging for TLS
- **DNSEndpoint**: DNS record for pr-<pr>-<repo>.ephemeral.fullstack.pw
- **ExternalSecret**: Vault secret sync (optional)

**Installation**:
```bash
export DNS_NAME=pr-42-cksbackend.ephemeral.fullstack.pw
export CLUSTER_IP=192.168.1.140
export CLUSTER_NAME=pr-cksbackend-42

envsubst < phase2-resources/*.yaml.tpl | kubectl apply -f - --kubeconfig <ephemeral-kubeconfig>

# Wait for DNS
timeout 300 bash -c 'until dig +short ${DNS_NAME} | grep -q 192.168.1; do sleep 5; done'
```

## Cluster Provisioning Flow

### Manual Provisioning (for testing)

```bash
# 1. Allocate IP
IP=$(./clusters/scripts/ip_pool_manager.sh allocate pr-test-1)

# 2. Render and apply Cluster API manifest
export CLUSTER_NAME=pr-test-1 CLUSTER_IP=$IP PR_NUMBER=1 REPOSITORY=test
envsubst < ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl | kubectl apply -f - --context tools

# 3. Wait for cluster ready
kubectl wait --for=condition=Ready cluster/pr-test-1 -n pr-test-1 --timeout=5m --context tools

# 4. Extract kubeconfig
kubectl get secret pr-test-1-kubeconfig -n pr-test-1 --context tools \
  -o jsonpath='{.data.value}' | base64 -d > /tmp/pr-test-1-kubeconfig

# 5. Install Phase 1 operators
kubectl apply -f ephemeral-clusters/phase1-operators/ --kubeconfig /tmp/pr-test-1-kubeconfig

# 6. Wait for CRDs
kubectl wait --for condition=established --timeout=3m --kubeconfig /tmp/pr-test-1-kubeconfig \
  crd/certificates.cert-manager.io \
  crd/dnsendpoints.externaldns.k8s.io \
  crd/secretstores.external-secrets.io

# 7. Install Phase 2 resources
export DNS_NAME=pr-1-test.ephemeral.fullstack.pw
envsubst < ephemeral-clusters/phase2-resources/*.yaml.tpl | kubectl apply -f - --kubeconfig /tmp/pr-test-1-kubeconfig

# 8. Wait for DNS
dig +short $DNS_NAME

# 9. Cleanup
kubectl delete cluster pr-test-1 -n pr-test-1 --context tools
./clusters/scripts/ip_pool_manager.sh release pr-test-1
```

### Automated Provisioning (via GitHub Actions)

**Status**: ✅ Complete - Workflows ready for use

Triggered via `repository_dispatch` from application repos:

```yaml
# From app repo (cks-backend, demo-apps, cks-frontend)
- name: Create Ephemeral Cluster
  uses: peter-evans/repository-dispatch@v2
  with:
    token: ${{ secrets.PAT_TOKEN }}
    repository: fullstack-pw/infra
    event-type: create_ephemeral_cluster
    client-payload: |
      {
        "pr_number": "${{ github.event.pull_request.number }}",
        "repository": "${{ github.event.repository.name }}",
        "branch": "${{ github.head_ref }}"
      }
```

## Configuration

### Cluster Specifications
- **Type**: K3s single-server (no separate workers)
- **Resources**: 4 CPU, 8GB RAM, 20GB disk
- **Network**: 192.168.1.140-149 (10 IPs)
- **Kubernetes**: v1.30.6+k3s1
- **Boot time**: ~2 minutes
- **Built-in**: Traefik, local-path-provisioner, servicelb

### Limits
- **Max concurrent clusters**: 10 (IP pool limit)
- **Max cluster lifetime**: 3 days (auto-cleanup)
- **Grace period after PR close**: 1 hour
- **Provisioning timeout**: 15 minutes
- **DNS propagation timeout**: 5 minutes

### DNS Configuration
- **Pattern**: `pr-<pr-number>-<repo>.ephemeral.fullstack.pw`
- **Providers**: Cloudflare (public) + Pi-hole (internal 192.168.1.3)
- **Management**: external-dns via Ingress annotations or DNSEndpoint CRD

### TLS Configuration
- **Issuer**: Let's Encrypt Staging (faster issuance, testing)
- **Ingress**: Traefik (K3s built-in)
- **Auto-renewal**: cert-manager

## Testing

### Test IP Pool Manager
```bash
export VAULT_ADDR=https://vault.fullstack.pw
export VAULT_TOKEN=<token>

./clusters/scripts/ip_pool_manager.sh list
./clusters/scripts/ip_pool_manager.sh check-capacity
./clusters/scripts/ip_pool_manager.sh allocate pr-test-1
./clusters/scripts/ip_pool_manager.sh list
./clusters/scripts/ip_pool_manager.sh release pr-test-1
```

### Test Cluster Provisioning
Use k3s-test cluster as reference:

```bash
# Inspect k3s-test structure
kubectl get cluster k3s-test -n k3s-test --context tools -o yaml
kubectl get kthreescontrolplane -n k3s-test --context tools -o yaml
kubectl get proxmoxcluster -n k3s-test --context tools -o yaml

# Test template rendering
export CLUSTER_NAME=pr-test-1 CLUSTER_IP=192.168.1.140 PR_NUMBER=1 REPOSITORY=test
envsubst < ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl | kubectl apply --dry-run=client -f -
```

## TODO / Next Steps

### Immediate (Phase 1)
1. ✅ IP pool manager script
2. ✅ Cluster API manifest template
3. ✅ Complete Phase 1 operator manifests (cert-manager, external-dns, external-secrets)
4. ✅ Complete Phase 2 resource templates
5. ✅ Create GitHub Actions workflow (ephemeral-cluster.yml)
6. ⏳ Test full provisioning flow with manual commands

### Short-term (Phase 2)
7. Create application repo workflows (pr-ephemeral.yml for cks-backend, demo-apps, cks-frontend)
8. Create ArgoCD Application templates
9. Create kustomize ephemeral overlays in app repos
10. Implement scheduled cleanup workflow (ephemeral-cleanup.yml)

### Medium-term (Phase 3)
11. Add Grafana dashboard for ephemeral cluster metrics
12. Implement cluster hibernation (suspend VMs during inactivity)
13. Add resource quotas per cluster
14. Document troubleshooting guide

## Reference Implementation

The `k3s-test` cluster serves as a reference for understanding Cluster API object structure:

```bash
# View all k3s-test resources
kubectl get all -n k3s-test --context tools

# Get kubeconfig
kubectl get secret k3s-test-kubeconfig -n k3s-test --context tools \
  -o jsonpath='{.data.value}' | base64 -d

# Access cluster
kubectl get nodes --kubeconfig <kubeconfig>
```

## Security Considerations

- Ephemeral clusters isolated per PR (no cross-contamination)
- Kubeconfigs stored in Vault (encrypted at rest)
- IP pool prevents conflicts via CAS locking
- Auto-cleanup prevents abandoned clusters
- GitHub Actions uses secrets for Vault/Proxmox access
- Resource quotas prevent resource exhaustion

## Support

- **Plan**: /home/pedro/.claude/plans/zippy-noodling-bumblebee.md
- **Dev cluster**: kubectl --context dev
- **Tools cluster**: kubectl --context tools
- **Vault**: https://vault.fullstack.pw
- **DNS**: Cloudflare + Pi-hole (192.168.1.3)
