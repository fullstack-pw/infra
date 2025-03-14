#!/bin/bash

# Script to automatically update Ansible inventory based on Terraform output
# This script is called by the terraform-apply.yml workflow after terraform apply

set -e

# Directory where the inventory file is located
INVENTORY_FILE="proxmox/k8s.ini"

# Check if INVENTORY_FILE exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file $INVENTORY_FILE not found"
    exit 1
fi

# Parse Terraform output
echo "Getting Terraform outputs..."
cd proxmox
terraform output -json > /tmp/tf_output.json
cd ..

# Extract VM information
echo "Extracting VM information..."
VM_IPS=$(jq -r '.vm_ips.value | to_entries | map(select(.key | match("k8s-"))) | map("\(.value.ip=="" ? "Unknown" : (.value.ip | split("/")[0]))")' /tmp/tf_output.json)
VM_NAMES=$(jq -r '.vm_ips.value | to_entries | map(select(.key | match("k8s-"))) | map(.key | gsub("proxmox/vms/"; "") | gsub(".yaml"; ""))' /tmp/tf_output.json)

# Create arrays from JSON outputs
readarray -t IPS < <(echo $VM_IPS | jq -r '.[]')
readarray -t NAMES < <(echo $VM_NAMES | jq -r '.[]')

# Temporary file for new inventory
TMP_INVENTORY=$(mktemp)

# Keep the header and other non-host sections
grep -v "ansible_user" "$INVENTORY_FILE" > "$TMP_INVENTORY" || true

# Add hosts to their respective sections
for i in "${!NAMES[@]}"; do
    NAME="${NAMES[$i]}"
    IP="${IPS[$i]}"
    
    # Skip if IP is "Unknown" (VM is not yet provisioned with an IP)
    if [ "$IP" == "Unknown" ]; then
        echo "Skipping $NAME - IP not provisioned yet"
        continue
    fi
    
    # Extract the environment from the VM name (after k8s-)
    ENV=$(echo "$NAME" | sed -n 's/^k8s-\(.*\)/\1/p')
    
    # If there's no hyphen (like k01, k02, etc.), set env to "sandbox"
    if [ -z "$ENV" ]; then
        if [[ "$NAME" =~ ^k[0-9]+ ]]; then
            ENV="sandbox"
        else
            echo "Skipping $NAME - doesn't follow naming convention"
            continue
        fi
    fi
    
    # Check if section already exists
    if ! grep -q "^\[$ENV\]" "$TMP_INVENTORY"; then
        echo "" >> "$TMP_INVENTORY"
        echo "[$ENV]" >> "$TMP_INVENTORY"
    fi
    
    # Add the host to the section
    echo "$IP ansible_user=suporte" >> "$TMP_INVENTORY"
done

# Ensure k3s-clusters section includes all environments
if ! grep -q "^\[k3s-clusters:children\]" "$TMP_INVENTORY"; then
    echo "" >> "$TMP_INVENTORY"
    echo "[k3s-clusters:children]" >> "$TMP_INVENTORY"
    # Add all environments
    for ENV in $(grep -o '^\[[a-zA-Z0-9_-]*\]' "$TMP_INVENTORY" | tr -d '[]' | grep -v "k3s-clusters"); do
        if [ "$ENV" != "k3s-clusters" ]; then
            echo "$ENV" >> "$TMP_INVENTORY"
        fi
    done
fi

# Replace the original inventory with the new one
mv "$TMP_INVENTORY" "$INVENTORY_FILE"

echo "Inventory file updated: $INVENTORY_FILE"
cat "$INVENTORY_FILE"