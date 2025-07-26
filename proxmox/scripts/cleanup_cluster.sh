#!/bin/bash
# proxmox/scripts/cleanup_cluster.sh
# Generic cluster cleanup script

CLUSTER_PATTERN=$1
INVENTORY_FILE="proxmox/k8s.ini"

if [ -z "$CLUSTER_PATTERN" ]; then
    echo "Usage: $0 <cluster_pattern>"
    echo "Example: $0 k8s-testing"
    exit 1
fi

echo "Cleaning up cluster with pattern: $CLUSTER_PATTERN"

# Remove hosts from inventory
sed -i "/^${CLUSTER_PATTERN}/d" $INVENTORY_FILE

# Remove empty group sections
sed -i '/^\[.*\]$/{ 
    N
    /^\[.*\]\n$/d
}' $INVENTORY_FILE

# Clean new_hosts.txt
if [ -f "proxmox/new_hosts.txt" ]; then
    sed -i "/^${CLUSTER_PATTERN}/d" proxmox/new_hosts.txt
fi

echo "Cleanup completed for pattern: $CLUSTER_PATTERN"