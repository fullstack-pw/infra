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
terraform output -json > ../tf_output.json
cd ..

# Debug: Display the structure of the Terraform output
echo "Debug: Terraform output structure"
jq 'keys' tf_output.json

# Check for VM output format and determine the correct JQ query
echo "Analyzing output structure..."

# Try multiple approaches to extract VM information correctly
if jq -e '.vm_ips.value | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found vm_ips as object structure"
    
    # Extract VM data using direct object access
    VM_DATA=$(jq -c '.vm_ips.value | to_entries | map({key: .key, ip: .value})' tf_output.json)
    
    echo "Debug - VM Data from object format:"
    echo "$VM_DATA" | jq '.'
    
elif jq -e '.vm_ips | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found vm_ips object structure without value wrapper"
    
    # Extract VM data from direct vm_ips object
    VM_DATA=$(jq -c '.vm_ips | to_entries | map({key: .key, ip: .value})' tf_output.json)
    
    echo "Debug - VM Data from direct object format:"
    echo "$VM_DATA" | jq '.'
    
elif jq -e '.k8s_nodes.value | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found k8s_nodes object structure"
    
    # Try k8s_nodes output which might have a different structure
    VM_DATA=$(jq -c '.k8s_nodes.value | to_entries | map({key: .key, ip: .value.ip})' tf_output.json)
    
    echo "Debug - VM Data from k8s_nodes format:"
    echo "$VM_DATA" | jq '.'
    
else
    # Try to find any output that might contain VM information
    echo "No standard format found, searching for any VM-related data..."
    
    # Print all keys to help troubleshoot
    echo "Available keys in Terraform output:"
    jq 'keys[]' tf_output.json
    
    # Check if any key contains "ip" or "vm" in its name
    VM_KEYS=$(jq 'keys | map(select(. | contains("ip") or contains("vm") or contains("k8s")))' tf_output.json)
    
    echo "Potential VM keys found: $VM_KEYS"
    
    if [ -n "$VM_KEYS" ] && [ "$VM_KEYS" != "[]" ]; then
        # Take the first key that looks promising
        FIRST_KEY=$(echo "$VM_KEYS" | jq -r '.[0]')
        echo "Using $FIRST_KEY for VM data extraction"
        
        # Try to extract using this key
        VM_DATA=$(jq -c --arg key "$FIRST_KEY" '.[$key] | to_entries | map({key: .key, ip: .value})' tf_output.json)
        
        echo "Debug - VM Data from alternate format:"
        echo "$VM_DATA" | jq '.'
    else
        echo "Error: Could not find VM IP information in Terraform output"
        # Print the entire output to help diagnose issues
        echo "Full Terraform output:"
        cat tf_output.json
        exit 1
    fi
fi

# Extract VM names and IPs from the VM_DATA
echo "Extracting VM names and IPs..."

# Get k8s- names and IPs
VM_NAMES=$(echo "$VM_DATA" | jq -r '[.[] | .key | select(contains("k8s-"))]')
VM_IPS=$(echo "$VM_DATA" | jq -r '[.[] | select(.key | contains("k8s-")) | .ip]')

echo "Debug - VM Names:"
echo "$VM_NAMES" | jq '.'
echo "Debug - VM IPs:"
echo "$VM_IPS" | jq '.'

# Create arrays from JSON outputs
readarray -t NAMES < <(echo "$VM_NAMES" | jq -r '.[]')
readarray -t IPS < <(echo "$VM_IPS" | jq -r '.[]')

echo "Debug - Names array contents:"
printf '%s\n' "${NAMES[@]}"
echo "Debug - IPs array contents:"
printf '%s\n' "${IPS[@]}"

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
    
    # Skip if IP is empty, null, or "Unknown"
    if [ -z "$IP" ] || [ "$IP" == "null" ] || [ "$IP" == "Unknown" ]; then
        echo "Skipping $NAME - IP not provisioned yet"
        continue
    fi
    
    # Extract clean IP if it's in format like 'ip=192.168.1.12/24,gw=192.168.1.1'
    if [[ "$IP" == *"ip="* ]]; then
        CLEAN_IP=$(echo "$IP" | grep -o 'ip=[^,/]*' | cut -d= -f2)
        if [ -n "$CLEAN_IP" ]; then
            echo "Extracted clean IP $CLEAN_IP from $IP"
            IP="$CLEAN_IP"
        fi
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