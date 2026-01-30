# Ephemeral Clusters Quick Start Guide

## Prerequisites

- Vault token with read/write access
- kubectl access to tools cluster
- Decoded secrets in `clusters/tmp/`

## Manual Testing

### 1. Provision a Test Cluster

```bash
cd /home/pedro/repos/infra

# Run the provisioning script
./ephemeral-clusters/test-provisioning.sh pr-test-manual 999 test

# This will:
# - Allocate IP from pool (192.168.1.140-149)
# - Create K3s cluster via Cluster API
# - Install 4 operators (cert-manager, external-dns, external-secrets, CloudNativePG)
# - Install Phase 2 resources (ClusterIssuer, DNSEndpoint, ExternalSecret, PostgreSQL)
# - Wait for DNS propagation
# - Total time: ~7-8 minutes
```

### 2. Access the Cluster

```bash
# Check cluster status
kubectl get nodes --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check operators
kubectl get pods -A --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check PostgreSQL
kubectl get cluster -n default --kubeconfig /tmp/pr-test-manual-kubeconfig
kubectl get pods -l postgresql=postgres --kubeconfig /tmp/pr-test-manual-kubeconfig
```

### 3. Connect to PostgreSQL

```bash
# Get PostgreSQL credentials
kubectl get secret postgres-app-user -n default \
  --kubeconfig /tmp/pr-test-manual-kubeconfig \
  -o jsonpath='{.data.password}' | base64 -d

# Connect via psql (from within the cluster or via port-forward)
kubectl port-forward svc/postgres-rw 5432:5432 \
  --kubeconfig /tmp/pr-test-manual-kubeconfig
psql postgresql://app:password@localhost:5432/app
```

### 4. Deploy an Application

```bash
# Example: Deploy a simple app with PostgreSQL
cat <<EOF | kubectl apply --kubeconfig /tmp/pr-test-manual-kubeconfig -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: postgres:16-alpine
        command: ["sleep", "3600"]
        env:
        - name: PGHOST
          value: "postgres-rw"
        - name: PGUSER
          value: "app"
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-app-user
              key: password
        - name: PGDATABASE
          value: "app"
EOF
```

### 5. Test DNS

```bash
# Check DNS resolution
dig +short pr-999-test.ephemeral.fullstack.pw

# Should return the allocated IP (192.168.1.14X)
```

### 6. Cleanup

```bash
# Run the cleanup script
./ephemeral-clusters/test-cleanup.sh pr-test-manual

# This will:
# - Delete Cluster API resources
# - Release IP back to pool
# - Remove kubeconfig from Vault
# - Clean up local files
```

## GitHub Actions Integration

### Trigger from Application Repo

```bash
# From your application repo (cks-backend, demo-apps, etc.)
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/fullstack-pw/infra/dispatches \
  -d '{
    "event_type": "create_ephemeral_cluster",
    "client_payload": {
      "pr_number": "42",
      "repository": "cks-backend",
      "branch": "feature/new-api"
    }
  }'
```

### Monitor Cluster Creation

```bash
# Watch the workflow
gh run list --repo fullstack-pw/infra --workflow ephemeral-cluster.yml

# View logs
gh run view <run-id> --repo fullstack-pw/infra --log
```

## IP Pool Management

### Check Available IPs

```bash
export VAULT_ADDR=https://vault.fullstack.pw
export VAULT_TOKEN=$(jq -r '.VAULT_TOKEN' clusters/tmp/common_secrets.json)

./clusters/scripts/ip_pool_manager.sh list
./clusters/scripts/ip_pool_manager.sh check-capacity
```

### Manual IP Operations

```bash
# Allocate IP
./clusters/scripts/ip_pool_manager.sh allocate pr-mytest-1

# Release IP
./clusters/scripts/ip_pool_manager.sh release pr-mytest-1
```

## Troubleshooting

### Cluster Not Ready

```bash
# Check Cluster API status
kubectl get cluster pr-test-manual -n pr-test-manual --context tools -o yaml

# Check events
kubectl get events -n pr-test-manual --context tools --sort-by='.lastTimestamp'

# Check VM on Proxmox
# VMs will be in range 401-450 with names like pr-test-manual-*
```

### Operators Not Installing

```bash
# Check if kustomize build works
kubectl kustomize ephemeral-clusters/phase1-operators/

# Check operator pods
kubectl get pods -n cert-manager --kubeconfig /tmp/pr-test-manual-kubeconfig
kubectl get pods -n external-dns --kubeconfig /tmp/pr-test-manual-kubeconfig
kubectl get pods -n external-secrets --kubeconfig /tmp/pr-test-manual-kubeconfig
kubectl get pods -n cnpg-system --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check logs
kubectl logs -n cnpg-system deployment/cnpg-controller-manager \
  --kubeconfig /tmp/pr-test-manual-kubeconfig
```

### PostgreSQL Not Starting

```bash
# Check cluster status
kubectl get cluster postgres -n default --kubeconfig /tmp/pr-test-manual-kubeconfig -o yaml

# Check pods
kubectl get pods -l postgresql=postgres --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check logs
kubectl logs -l postgresql=postgres --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check PVC
kubectl get pvc --kubeconfig /tmp/pr-test-manual-kubeconfig
```

### DNS Not Resolving

```bash
# Check DNSEndpoint
kubectl get dnsendpoint --kubeconfig /tmp/pr-test-manual-kubeconfig -o yaml

# Check external-dns logs
kubectl logs -n external-dns deployment/external-dns-cloudflare \
  --kubeconfig /tmp/pr-test-manual-kubeconfig

# Check Cloudflare directly
curl -X GET "https://api.cloudflare.com/client/v4/zones/<zone-id>/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq '.result[] | select(.name | contains("ephemeral"))'
```

## Resource Limits

- **Max concurrent clusters**: 10 (IP pool: 192.168.1.140-149)
- **Max cluster lifetime**: 3 days (auto-cleanup)
- **Grace period after PR close**: 1 hour
- **Per cluster resources**:
  - 4 CPU cores
  - 8GB RAM
  - 20GB root disk
  - 5GB PostgreSQL storage

## Key Files

- **Provisioning script**: `ephemeral-clusters/test-provisioning.sh`
- **Cleanup script**: `ephemeral-clusters/test-cleanup.sh`
- **IP pool manager**: `clusters/scripts/ip_pool_manager.sh`
- **Cluster template**: `ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl`
- **Phase 1 operators**: `ephemeral-clusters/phase1-operators/`
- **Phase 2 resources**: `ephemeral-clusters/phase2-resources/`
- **Workflows**: `.github/workflows/ephemeral-*.yml`

## Next Steps

1. Run test provisioning: `./ephemeral-clusters/test-provisioning.sh pr-test-1`
2. Verify all components working
3. Test with writer-app or another PostgreSQL app
4. Integrate with application repositories
5. Create application-specific kustomize overlays
6. Test full PR workflow

## Support

- **Main README**: `ephemeral-clusters/README.md`
- **Application integration**: `ephemeral-clusters/APPLICATION_REPO_INTEGRATION.md`
- **Plan document**: `/home/pedro/.claude/plans/zippy-noodling-bumblebee.md`
- **IP pool status**: `./clusters/scripts/ip_pool_manager.sh list`
