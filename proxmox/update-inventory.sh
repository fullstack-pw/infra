#!/bin/bash

# Script to manage Ansible inventory based on Terraform output
# Handles both adding new hosts and removing destroyed ones

set -e

# Directory where the inventory file is located
INVENTORY_FILE="proxmox/k8s.ini"
NEW_HOSTS_FILE="proxmox/new_hosts.txt"

# Check if INVENTORY_FILE exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file $INVENTORY_FILE not found"
    exit 1
fi

# Backup inventory before changes
cp "$INVENTORY_FILE" "${INVENTORY_FILE}.backup"

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
        echo "No VM data found in Terraform output - possibly all VMs destroyed"
        VM_DATA='[]'
    fi
fi

# Extract VM names and IPs from the VM_DATA
echo "Extracting VM names and IPs..."
if [ "$VM_DATA" != "[]" ]; then
    VM_NAMES=$(echo "$VM_DATA" | jq -r '[.[] | .key]')
    VM_IPS=$(echo "$VM_DATA" | jq -r '[.[] | .ip]')

    echo "Debug - VM Names:"
    echo "$VM_NAMES" | jq '.'
    echo "Debug - VM IPs:"
    echo "$VM_IPS" | jq '.'

    # Create arrays from JSON outputs
    readarray -t NAMES < <(echo "$VM_NAMES" | jq -r '.[]')
    readarray -t IPS < <(echo "$VM_IPS" | jq -r '.[]')
else
    echo "No VMs found in terraform output"
    NAMES=()
    IPS=()
fi

# Get current VMs from inventory (excluding comments and group headers)
CURRENT_VMS=$(grep -E '^[a-zA-Z0-9-]+ ansible_host=' "$INVENTORY_FILE" | awk '{print $1}' | sort)
NEW_VMS=()
if [ ${#NAMES[@]} -gt 0 ]; then
    printf '%s\n' "${NAMES[@]}" | sort > /tmp/new_vms.txt
    NEW_VMS=($(cat /tmp/new_vms.txt))
fi

# Determine VMs to remove (exist in inventory but not in terraform)
VMS_TO_REMOVE=()
if [ -n "$CURRENT_VMS" ]; then
    echo "$CURRENT_VMS" > /tmp/current_vms.txt
    if [ ${#NEW_VMS[@]} -gt 0 ]; then
        VMS_TO_REMOVE=($(comm -23 /tmp/current_vms.txt /tmp/new_vms.txt))
    else
        # If no new VMs, all current VMs should be removed
        VMS_TO_REMOVE=($(cat /tmp/current_vms.txt))
    fi
fi

# Function to remove VM from inventory
remove_vm_from_inventory() {
    local vm_name=$1
    echo "Removing $vm_name from inventory..."
    
    # Remove the host line
    sed -i "/^${vm_name} ansible_host=/d" "$INVENTORY_FILE"
    
    # Remove from group sections (but not group headers)
    sed -i "/^\[.*\]$/!s/^${vm_name}$//g" "$INVENTORY_FILE"
    
    # Remove empty lines that might have been created
    sed -i '/^$/N;/^\n$/d' "$INVENTORY_FILE"
}

# Function to add haproxy entries
add_haproxy_entry() {
    local vm_name=$1
    local ip=$2
    
    echo "Adding HAProxy: $vm_name"
    
    # Add to individual hosts section if not exists
    if ! grep -q "^$vm_name " "$INVENTORY_FILE"; then
        sed -i "/^# Individual hosts/a $vm_name ansible_host=$ip ansible_user=suporte" "$INVENTORY_FILE"
    fi
    
    # Add to haproxy group
    if ! grep -q "^\[haproxy\]" "$INVENTORY_FILE"; then
        echo "" >> "$INVENTORY_FILE"
        echo "[haproxy]" >> "$INVENTORY_FILE"
        echo "$vm_name" >> "$INVENTORY_FILE"
    else
        # Add to existing group if not already there
        if ! grep -A 20 "^\[haproxy\]" "$INVENTORY_FILE" | grep -q "^$vm_name$"; then
            sed -i "/^\[haproxy\]/a $vm_name" "$INVENTORY_FILE"
        fi
    fi
}

# Function to add Talos cluster groups
add_talos_cluster_groups() {
    local vm_name=$1
    local ip=$2
    
    # Handle new talos naming convention: talos-CLUSTERNAME-CLUSTERFUNCTION-number
    if [[ $vm_name =~ ^talos-([^-]+)-(cp|worker)([0-9]+)$ ]]; then
        local cluster_name="${BASH_REMATCH[1]}"
        local node_type="${BASH_REMATCH[2]}"
        local node_number="${BASH_REMATCH[3]}"
        
        echo "Adding Talos node: $vm_name to cluster: $cluster_name"
        
        local group_name
        if [[ $node_type == "cp" ]]; then
            group_name="${cluster_name}_control_plane"
        else
            group_name="${cluster_name}_workers"
        fi
        
        # Add to individual hosts section if not exists
        if ! grep -q "^$vm_name " "$INVENTORY_FILE"; then
            sed -i "/^# Individual hosts/a $vm_name ansible_host=$ip ansible_user=suporte" "$INVENTORY_FILE"
        fi
        
        # Create group if not exists
        if ! grep -q "^\[${group_name}\]" "$INVENTORY_FILE"; then
            echo "" >> "$INVENTORY_FILE"
            echo "[${group_name}]" >> "$INVENTORY_FILE"
            echo "$vm_name" >> "$INVENTORY_FILE"
        else
            # Add to existing group if not already there
            if ! grep -A 20 "^\[${group_name}\]" "$INVENTORY_FILE" | grep -q "^$vm_name$"; then
                sed -i "/^\[${group_name}\]/a $vm_name" "$INVENTORY_FILE"
            fi
        fi
        
        # Also add to main cluster group
        if ! grep -q "^\[${cluster_name}\]" "$INVENTORY_FILE"; then
            echo "" >> "$INVENTORY_FILE"
            echo "[${cluster_name}]" >> "$INVENTORY_FILE"
            echo "$vm_name" >> "$INVENTORY_FILE"
        else
            if ! grep -A 20 "^\[${cluster_name}\]" "$INVENTORY_FILE" | grep -q "^$vm_name$"; then
                sed -i "/^\[${cluster_name}\]/a $vm_name" "$INVENTORY_FILE"
            fi
        fi
    fi
}

# Function to add K3s single-machine cluster groups
add_k3s_single_machine_groups() {
    local vm_name=$1
    local ip=$2
    
    # Handle VMs starting with k8s that are NOT talos clusters
    if [[ $vm_name =~ ^k8s-([^-]+)$ ]] || [[ $vm_name =~ ^k8s-([^-]+)-[0-9]+$ ]]; then
        echo "Adding K3s single-machine cluster: $vm_name"
        
        # Add to individual hosts section if not exists
        if ! grep -q "^$vm_name " "$INVENTORY_FILE"; then
            sed -i "/^# Individual hosts/a $vm_name ansible_host=$ip ansible_user=suporte" "$INVENTORY_FILE"
        fi
        
        # Add to k3s group
        if ! grep -q "^\[k3s\]" "$INVENTORY_FILE"; then
            echo "" >> "$INVENTORY_FILE"
            echo "[k3s]" >> "$INVENTORY_FILE"
            echo "$vm_name" >> "$INVENTORY_FILE"
        else
            # Add to existing group if not already there
            if ! grep -A 20 "^\[k3s\]" "$INVENTORY_FILE" | grep -q "^$vm_name$"; then
                sed -i "/^\[k3s\]/a $vm_name" "$INVENTORY_FILE"
            fi
        fi
    fi
}

# Function to clean empty groups - minimal approach
clean_empty_groups() {
    echo "Cleaning empty groups..."
    # Remove only truly empty groups (group header followed immediately by another group header or end of file)
    # But be more careful about it
    python3 -c "
import re
import sys

with open('$INVENTORY_FILE', 'r') as f:
    lines = f.readlines()

result = []
i = 0
while i < len(lines):
    line = lines[i].strip()
    
    # If this is a group header
    if re.match(r'^\[.*\]$', line):
        # Look ahead to see if this group is empty
        j = i + 1
        has_members = False
        
        # Check following lines until next group or end
        while j < len(lines):
            next_line = lines[j].strip()
            if re.match(r'^\[.*\]$', next_line):  # Next group found
                break
            elif next_line and not next_line.startswith('#') and not next_line.startswith('ansible_'):
                has_members = True
                break
            j += 1
        
        # Only add group if it has members or is [all:vars]
        if has_members or '[all:vars]' in line:
            result.append(lines[i])
            # Add all lines until next group
            k = i + 1
            while k < len(lines):
                if re.match(r'^\[.*\]$', lines[k].strip()) and k != i:
                    break
                result.append(lines[k])
                k += 1
            i = k
        else:
            # Skip empty group
            while i + 1 < len(lines) and not re.match(r'^\[.*\]$', lines[i + 1].strip()):
                i += 1
            i += 1
    else:
        result.append(lines[i])
        i += 1

with open('$INVENTORY_FILE', 'w') as f:
    f.writelines(result)
"
}

# Remove VMs that no longer exist
if [ ${#VMS_TO_REMOVE[@]} -gt 0 ]; then
    echo "Removing VMs that no longer exist..."
    for vm_name in "${VMS_TO_REMOVE[@]}"; do
        if [ -n "$vm_name" ]; then
            remove_vm_from_inventory "$vm_name"
        fi
    done
fi

# Clear new_hosts.txt
> "$NEW_HOSTS_FILE"

# Add new VMs and update existing ones
if [ ${#NAMES[@]} -gt 0 ]; then
    echo "Processing VMs from terraform output..."
    
    for i in "${!NAMES[@]}"; do
        name="${NAMES[i]}"
        ip="${IPS[i]}"
        
        # Clean up IP (remove any extra formatting)
        ip=$(echo $ip | sed 's/ip=//g' | cut -d',' -f1 | cut -d'/' -f1)
        
        echo "Processing VM: $name with IP: $ip"
        
        # Skip if IP is malformed
        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Warning: Skipping $name - invalid IP format: $ip"
            continue
        fi
        
        # Check if this is a new VM
        if ! grep -q "^$name " "$INVENTORY_FILE"; then
            echo "New VM detected: $name"
            echo "$ip,$name" >> "$NEW_HOSTS_FILE"
        fi
        
# Handle different VM types
        if [[ $name =~ ^haproxy- ]]; then
            add_haproxy_entry "$name" "$ip"
        elif [[ $name =~ ^talos-([^-]+)-(cp|worker)([0-9]+)$ ]]; then
            add_talos_cluster_groups "$name" "$ip"
        elif [[ $name =~ ^k8s-([^-]+)$ ]]; then
            add_k3s_single_machine_groups "$name" "$ip"
        else
            # Handle regular VMs (existing logic)
            echo "Adding regular VM: $name"
            # Check if entry exists, if not add it
            if ! grep -q "^$name " "$INVENTORY_FILE"; then
                sed -i "/^# Individual hosts/a $name ansible_host=$ip ansible_user=suporte" "$INVENTORY_FILE"
            else
                # Update existing entry
                sed -i "s/^$name ansible_host=.* ansible_user=suporte/$name ansible_host=$ip ansible_user=suporte/" "$INVENTORY_FILE"
            fi
        fi
    done
else
    echo "No VMs to process"
fi

# Clean up empty groups
clean_empty_groups

# Clean up temporary files
rm -f /tmp/current_vms.txt /tmp/new_vms.txt

# Validate final inventory
echo "Validating inventory file..."
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "❌ Inventory validation failed - file does not exist"
    mv "${INVENTORY_FILE}.backup" "$INVENTORY_FILE"
    exit 1
fi

# Show inventory content for debugging
echo "Current inventory content:"
cat "$INVENTORY_FILE"

# Try ansible-inventory validation with detailed error output
VALIDATION_OUTPUT=$(ansible-inventory -i "$INVENTORY_FILE" --list 2>&1)
VALIDATION_EXIT_CODE=$?

if [ $VALIDATION_EXIT_CODE -eq 0 ]; then
    echo "✅ Inventory validation successful"
else
    echo "❌ Inventory validation failed with exit code: $VALIDATION_EXIT_CODE"
    echo "Validation error output:"
    echo "$VALIDATION_OUTPUT"
    echo "Restoring backup..."
    mv "${INVENTORY_FILE}.backup" "$INVENTORY_FILE"
    exit 1
fi

# Remove backup if everything went well
rm -f "${INVENTORY_FILE}.backup"

echo "Inventory update completed successfully"
if [ -s "$NEW_HOSTS_FILE" ]; then
    echo "New hosts added:"
    cat "$NEW_HOSTS_FILE"
else
    echo "No new hosts were added"
fi