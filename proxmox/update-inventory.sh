#!/bin/bash

# Script to automatically update Ansible inventory based on Terraform output
# This script is called by the terraform-apply.yml workflow after terraform apply

set -e

# Directory where the inventory file is located
INVENTORY_FILE="proxmox/k8s.ini"
NEW_HOSTS_FILE="proxmox/new_hosts.txt"

# Check if INVENTORY_FILE exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file $INVENTORY_FILE not found"
    exit 1
fi

# Save the old inventory for comparison
cp "$INVENTORY_FILE" "${INVENTORY_FILE}.old"

# Parse Terraform output
echo "Getting Terraform outputs..."
cd proxmox
terraform output -json > tf_output.json
cd ..

# Extract VM information - Fix JQ syntax issues
echo "Extracting VM information..."
# Fixed JQ commands to avoid string interpolation issues
VM_IPS=$(jq -r '.vm_ips.value | to_entries | map(select(.key | contains("k8s-"))) | map(if .value.ip == "" then "Unknown" else (.value.ip | split("/")[0]) end)' tf_output.json)
VM_NAMES=$(jq -r '.vm_ips.value | to_entries | map(select(.key | contains("k8s-"))) | map(.key | gsub("proxmox/vms/"; "") | gsub(".yaml"; ""))' tf_output.json)

# Create arrays from JSON outputs
readarray -t IPS < <(echo $VM_IPS | jq -r '.[]')
readarray -t NAMES < <(echo $VM_NAMES | jq -r '.[]')

# Debug array contents
echo "Debug - IPS array contents:"
printf '%s\n' "${IPS[@]}"
echo "Debug - NAMES array contents:"
printf '%s\n' "${NAMES[@]}"

# Track new hosts
> "$NEW_HOSTS_FILE"

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

    # Check if this host is already in the old inventory
    if ! grep -q "$IP ansible_user=suporte" "${INVENTORY_FILE}.old"; then
        echo "New host detected: $NAME at $IP"
        echo "$IP,$ENV" >> "$NEW_HOSTS_FILE"
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

# Cleanup
rm "${INVENTORY_FILE}.old"

echo "Inventory file updated: $INVENTORY_FILE"
if [ -s "$NEW_HOSTS_FILE" ]; then
    echo "New hosts detected:"
    cat "$NEW_HOSTS_FILE"
else
    echo "No new hosts detected"
fi