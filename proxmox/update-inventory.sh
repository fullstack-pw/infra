#!/bin/bash

# Script to add new hosts to Ansible inventory based on Terraform output
# This script only adds new hosts without restructuring the inventory

set -e

# Directory where the inventory file is located
INVENTORY_FILE="proxmox/k8s.ini"
NEW_HOSTS_FILE="proxmox/new_hosts.txt"

# Check if INVENTORY_FILE exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file $INVENTORY_FILE not found"
    exit 1
fi

# Parse Terraform output
echo "Getting Terraform outputs..."
cd proxmox
terraform output -json > ../tf_output.json
cd ..

echo "Analyzing output structure..."

# Try multiple approaches to extract VM information correctly
if jq -e '.vm_ips.value | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found vm_ips as object structure"
    VM_DATA=$(jq -c '.vm_ips.value | to_entries | map({key: .key, ip: .value})' tf_output.json)
elif jq -e '.vm_ips | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found vm_ips object structure without value wrapper"
    VM_DATA=$(jq -c '.vm_ips | to_entries | map({key: .key, ip: .value})' tf_output.json)
elif jq -e '.k8s_nodes.value | type == "object"' tf_output.json > /dev/null 2>&1; then
    echo "Found k8s_nodes object structure"
    VM_DATA=$(jq -c '.k8s_nodes.value | to_entries | map({key: .key, ip: .value.ip})' tf_output.json)
else
    echo "No standard format found, searching for any VM-related data..."
    VM_KEYS=$(jq 'keys | map(select(. | contains("ip") or contains("vm") or contains("k8s")))' tf_output.json)
    echo "Potential VM keys found: $VM_KEYS"
    
    if [ -n "$VM_KEYS" ] && [ "$VM_KEYS" != "[]" ]; then
        FIRST_KEY=$(echo "$VM_KEYS" | jq -r '.[0]')
        echo "Using $FIRST_KEY for VM data extraction"
        VM_DATA=$(jq -c --arg key "$FIRST_KEY" '.[$key] | to_entries | map({key: .key, ip: .value})' tf_output.json)
    else
        echo "Error: Could not find VM IP information in Terraform output"
        cat tf_output.json
        exit 1
    fi
fi

# Extract VM names and IPs from the VM_DATA
echo "Extracting VM names and IPs..."
VM_NAMES=$(echo "$VM_DATA" | jq -r '[.[] | .key]')
VM_IPS=$(echo "$VM_DATA" | jq -r '[.[] | .ip]')

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

# Initialize a flag to check if we found new hosts
FOUND_NEW_HOSTS=false

# Check for new hosts and add them to NEW_HOSTS_FILE
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
    
    # Format host entry as in the original inventory (checking if name already has .yaml)
    if [[ "$NAME" == *".yaml" ]]; then
        HOST_ENTRY="${NAME} ${IP} ansible_user=suporte"
    else
        HOST_ENTRY="${NAME}.yaml ${IP} ansible_user=suporte"
    fi
    
    # Check if this host is already in the inventory
    if ! grep -q "$IP.*ansible_user=suporte" "$INVENTORY_FILE"; then
        echo "New host detected: $NAME at $IP"
        echo "$IP,$NAME" >> "$NEW_HOSTS_FILE"
        FOUND_NEW_HOSTS=true
        
        # Create a temporary file with the new host at the beginning
        TMP_FILE=$(mktemp)
        echo "$HOST_ENTRY" > "$TMP_FILE"
        cat "$INVENTORY_FILE" >> "$TMP_FILE"
        
        # Replace the original inventory with the updated one
        mv "$TMP_FILE" "$INVENTORY_FILE"
    fi
done

# Add Talos cluster group logic
add_talos_cluster_groups() {
    local vm_name=$1
    local ip=$2
    
    # Handle testing cluster specifically
    if [[ $vm_name =~ ^k8s-testing-(cp|w)[0-9]+$ ]]; then
        local role
        if [[ $vm_name =~ cp[0-9]+$ ]]; then
            role="control_plane"
        else
            role="workers"  
        fi
        
        # Add to testing_control_plane or testing_workers group
        if ! grep -q "^\[testing_${role}\]" $INVENTORY_FILE; then
            echo "[testing_${role}]" >> $INVENTORY_FILE
        fi
        
        # Add host to the appropriate group section
        sed -i "/^\[testing_${role}\]/a $vm_name" $INVENTORY_FILE
    fi
}

# Add HAProxy handling
add_haproxy_entry() {
    local vm_name=$1
    local ip=$2
    
    if [[ $vm_name =~ ^haproxy- ]]; then
        # Extract cluster name from HAProxy VM name
        local cluster_name=$(echo $vm_name | sed 's/^haproxy-//')
        
        # Add HAProxy entry if not exists
        if ! grep -q "^$vm_name " $INVENTORY_FILE; then
            # Add to individual hosts section (at the top)
            sed -i "/^# Individual hosts/a $vm_name ansible_host=$ip ansible_user=suporte" $INVENTORY_FILE
        fi
        
        # Create/update HAProxy group for this cluster
        if ! grep -q "^\[haproxy_${cluster_name}\]" $INVENTORY_FILE; then
            echo "" >> $INVENTORY_FILE
            echo "[haproxy_${cluster_name}]" >> $INVENTORY_FILE
            echo "$vm_name" >> $INVENTORY_FILE
        fi
    fi
}


# Cleanup
rm -f tf_output.json

if [ "$FOUND_NEW_HOSTS" = true ]; then
    echo "Inventory file updated with new hosts: $INVENTORY_FILE"
    echo "New hosts detected:"
    cat "$NEW_HOSTS_FILE"
else
    echo "No new hosts detected. Inventory remains unchanged."
fi