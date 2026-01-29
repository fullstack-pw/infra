#!/usr/bin/env bash
set -euo pipefail

# Test cleanup script for ephemeral clusters

CLUSTER_NAME="${1:-pr-test-manual}"

echo "========================================="
echo "Ephemeral Cluster Cleanup"
echo "========================================="
echo "Cluster Name: $CLUSTER_NAME"
echo ""

# Setup Vault credentials
export VAULT_ADDR=https://vault.fullstack.pw
if [ -z "${VAULT_TOKEN:-}" ]; then
    echo "Reading VAULT_TOKEN from clusters/tmp/common_secrets.json..."
    export VAULT_TOKEN=$(jq -r '."kv/cluster-secret-store/secrets/VAULT_TOKEN".VAULT_TOKEN' clusters/tmp/common_secrets.json)
fi

# Step 1: Delete Cluster API resources
echo "Step 1: Deleting Cluster API resources..."
kubectl delete cluster $CLUSTER_NAME -n $CLUSTER_NAME --context tools --ignore-not-found=true

echo "Waiting for cluster deletion..."
kubectl wait --for=delete cluster/$CLUSTER_NAME -n $CLUSTER_NAME \
    --timeout=5m --context tools || true

kubectl delete namespace $CLUSTER_NAME --context tools --ignore-not-found=true
echo ""

# Step 2: Release IP
echo "Step 2: Releasing IP from pool..."
./clusters/scripts/ip_pool_manager.sh release "$CLUSTER_NAME"
echo ""

# Step 3: Remove kubeconfig from Vault
echo "Step 3: Removing kubeconfig from Vault..."
vault kv delete kv/ephemeral-clusters/${CLUSTER_NAME}/kubeconfig || true
echo ""

# Step 4: Remove local kubeconfig
echo "Step 4: Removing local kubeconfig file..."
rm -f /tmp/${CLUSTER_NAME}-kubeconfig
rm -f /tmp/${CLUSTER_NAME}-cluster.yaml
echo ""

echo "========================================="
echo "✅ Cleanup Complete!"
echo "========================================="
echo ""
./clusters/scripts/ip_pool_manager.sh list
echo ""
