#!/usr/bin/env bash
set -euo pipefail

# Test script for ephemeral cluster provisioning
# This follows the manual provisioning flow from README.md

CLUSTER_NAME="${1:-pr-test-manual}"
PR_NUMBER="${2:-999}"
REPOSITORY="${3:-test}"

echo "========================================="
echo "Ephemeral Cluster Test Provisioning"
echo "========================================="
echo "Cluster Name: $CLUSTER_NAME"
echo "PR Number: $PR_NUMBER"
echo "Repository: $REPOSITORY"
echo ""

# Setup Vault credentials
export VAULT_ADDR=https://vault.fullstack.pw
if [ -z "${VAULT_TOKEN:-}" ]; then
    echo "Reading VAULT_TOKEN from clusters/tmp/common_secrets.json..."
    export VAULT_TOKEN=$(jq -r '."kv/cluster-secret-store/secrets/VAULT_TOKEN".VAULT_TOKEN' clusters/tmp/common_secrets.json)
fi

# Step 1: Check capacity
echo "Step 1: Checking IP pool capacity..."
./clusters/scripts/ip_pool_manager.sh check-capacity
CAPACITY_RESULT=$?
if [ "$CAPACITY_RESULT" -ne 0 ]; then
    echo "ERROR: IP pool exhausted!"
    exit 1
fi
echo ""

# Step 2: Allocate IP
echo "Step 2: Allocating IP from pool..."
CLUSTER_IP=$(./clusters/scripts/ip_pool_manager.sh allocate "$CLUSTER_NAME")
echo "Allocated control plane VIP: $CLUSTER_IP"

# Calculate node IP (VIP + 1)
IP_LAST_OCTET=$(echo "$CLUSTER_IP" | cut -d'.' -f4)
NODE_IP_LAST_OCTET=$((IP_LAST_OCTET + 1))
NODE_IP="192.168.1.${NODE_IP_LAST_OCTET}"
echo "Node IP: $NODE_IP"
echo ""

# Step 3: Render Cluster API manifest
echo "Step 3: Rendering Cluster API manifest..."
export CLUSTER_NAME
export CLUSTER_IP
export NODE_IP
export PR_NUMBER
export REPOSITORY
envsubst < ephemeral-clusters/cluster-api/k3s-cluster.yaml.tpl > /tmp/${CLUSTER_NAME}-cluster.yaml
echo "Manifest saved to: /tmp/${CLUSTER_NAME}-cluster.yaml"
echo ""

# Step 4: Apply to tools cluster
echo "Step 4: Applying Cluster API manifest to tools cluster..."
kubectl apply -f /tmp/${CLUSTER_NAME}-cluster.yaml --context tools
echo ""

# Step 4.5: Copy proxmox-credentials secret to namespace
echo "Step 4.5: Copying proxmox-credentials secret..."
kubectl --context tools get secret proxmox-credentials -n k3s-test -o json | \
  jq 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid, .metadata.ownerReferences, .metadata.finalizers) | .metadata.namespace = "'$CLUSTER_NAME'"' | \
  kubectl --context tools apply -f - > /dev/null 2>&1 || \
  echo "Warning: Could not copy proxmox-credentials (may already exist)"
echo ""

# Step 5: Wait for cluster available
echo "Step 5: Waiting for cluster to be available (max 5 minutes)..."
kubectl wait --for=condition=Available cluster/$CLUSTER_NAME -n $CLUSTER_NAME --timeout=5m --context tools
echo "Cluster is available!"
echo ""

# Step 6: Extract kubeconfig
echo "Step 6: Extracting kubeconfig..."
kubectl get secret ${CLUSTER_NAME}-kubeconfig -n $CLUSTER_NAME --context tools \
    -o jsonpath='{.data.value}' | base64 -d > /tmp/${CLUSTER_NAME}-kubeconfig
echo "Kubeconfig saved to: /tmp/${CLUSTER_NAME}-kubeconfig"
echo ""

# Step 7: Store kubeconfig in Vault
echo "Step 7: Storing kubeconfig in Vault..."
vault kv put kv/ephemeral-clusters/${CLUSTER_NAME}/kubeconfig \
    value=@/tmp/${CLUSTER_NAME}-kubeconfig
echo ""

# Step 8: Create Cloudflare secret
echo "Step 8: Creating Cloudflare API token secret..."
CF_TOKEN=$(jq -r '."kv/cloudflare"."api-token"' clusters/tmp/common_secrets.json)
kubectl create namespace external-dns \
    --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig \
    --dry-run=client -o yaml | kubectl apply --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig -f -
kubectl create secret generic cloudflare-api-token \
    --from-literal=api-token="$CF_TOKEN" \
    -n external-dns \
    --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig \
    --dry-run=client -o yaml | kubectl apply --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig -f -
echo ""

# Step 9: Install Phase 1 operators (without CloudNativePG)
echo "Step 9: Installing Phase 1 operators..."
kubectl apply -k ephemeral-clusters/phase1-operators/ --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig
echo ""

# Step 9.5: Install CloudNativePG via Helm
echo "Step 9.5: Installing CloudNativePG via Helm..."
helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
helm repo update cloudnative-pg >/dev/null 2>&1
helm install cnpg cloudnative-pg/cloudnative-pg \
    --namespace cnpg-system \
    --create-namespace \
    --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig \
    --wait --timeout=3m
echo ""

# Step 10: Wait for operators
echo "Step 10: Waiting for operators to be ready..."
echo "  - Waiting for cert-manager..."
kubectl wait --for=condition=Available deployment/cert-manager \
    -n cert-manager --timeout=3m --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig

echo "  - Waiting for external-dns..."
kubectl wait --for=condition=Available deployment/external-dns-cloudflare \
    -n external-dns --timeout=3m --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig

echo "  - Waiting for external-secrets..."
kubectl wait --for=condition=Available deployment/external-secrets \
    -n external-secrets --timeout=3m --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig

echo "  - Waiting for CloudNativePG..."
kubectl wait --for=condition=Available deployment/cnpg-cloudnative-pg \
    -n cnpg-system --timeout=3m --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig
echo "All operators ready!"
echo ""

# Step 11: Wait for CRDs
echo "Step 11: Waiting for CRDs to be established..."
kubectl wait --for condition=established --timeout=3m --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig \
    crd/certificates.cert-manager.io \
    crd/clusterissuers.cert-manager.io \
    crd/dnsendpoints.externaldns.k8s.io \
    crd/secretstores.external-secrets.io \
    crd/externalsecrets.external-secrets.io \
    crd/clusters.postgresql.cnpg.io \
    crd/backups.postgresql.cnpg.io
echo "All CRDs established!"
echo ""

# Step 12: Install Phase 2 resources
echo "Step 12: Installing Phase 2 resources..."
DNS_NAME="pr-${PR_NUMBER}-${REPOSITORY}.ephemeral.fullstack.pw"
export DNS_NAME

# Apply ClusterIssuer
kubectl apply -f ephemeral-clusters/phase2-resources/clusterissuer.yaml \
    --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig

# Apply templated resources
for f in ephemeral-clusters/phase2-resources/*.tpl; do
    envsubst < "$f"
done | kubectl apply --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig -f -
echo ""

# Step 13: Wait for DNS
echo "Step 13: Waiting for DNS propagation (max 5 minutes)..."
echo "DNS Name: $DNS_NAME -> $CLUSTER_IP"
timeout 300 bash -c "
    until dig +short $DNS_NAME | grep -q '$CLUSTER_IP'; do
        echo '  Still waiting...'
        sleep 5
    done
" || echo "DNS propagation timeout - may need more time"
echo ""

# Summary
echo "========================================="
echo "✅ Ephemeral Cluster Provisioning Complete!"
echo "========================================="
echo "Cluster Name:   $CLUSTER_NAME"
echo "Cluster IP:     $CLUSTER_IP"
echo "DNS Name:       $DNS_NAME"
echo "Kubeconfig:     /tmp/${CLUSTER_NAME}-kubeconfig"
echo ""
echo "Test the cluster:"
echo "  kubectl get nodes --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig"
echo "  kubectl get pods -A --kubeconfig /tmp/${CLUSTER_NAME}-kubeconfig"
echo ""
echo "Cleanup:"
echo "  ./ephemeral-clusters/test-cleanup.sh $CLUSTER_NAME"
echo ""
