#!/bin/bash
# proxmox/scripts/bootstrap_talos_cluster.sh
# Complete Talos cluster bootstrap for 3 control planes + 3 workers

set -e

# Configuration
CLUSTER_NAME="testing"
TALOS_VERSION="v1.10.3"

# Node IPs
CONTROL_PLANE_IPS=(
    "192.168.1.233"  # cp01
    "192.168.1.232"  # cp02  
    "192.168.1.235"  # cp03
)

WORKER_IPS=(
    "192.168.1.238"  # w01
    "192.168.1.231"  # w02
    "192.168.1.236"  # w03
)

# Cluster endpoint (use first control plane IP)
CLUSTER_ENDPOINT="192.168.1.233"  # UPDATE THIS
CONFIG_DIR="./talos-configs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install talosctl if not present
install_talosctl() {
    if ! command -v talosctl &> /dev/null; then
        log "Installing talosctl..."
        curl -sL https://talos.dev/install | sh
        # Add to PATH for current session
        export PATH=$PATH:$HOME/.local/bin
    else
        log "talosctl already installed"
    fi
}

# Generate Talos configurations
generate_configs() {
    log "Generating Talos configurations..."
    
    mkdir -p "$CONFIG_DIR"
    
    # First generate base config without patches
    talosctl gen config "$CLUSTER_NAME" "https://${CLUSTER_ENDPOINT}:6443" \
        --output-dir "$CONFIG_DIR" \
        --with-examples=false \
        --with-docs=false
    
    # Create patch file for additional configuration
    cat > "$CONFIG_DIR/patch.yaml" << 'EOF'
cluster:
  allowSchedulingOnControlPlanes: false
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
machine:
  network:
    nameservers:
      - 192.168.1.3
      - 8.8.8.8
  install:
    disk: /dev/sda
    wipe: false
  kubelet:
    extraArgs:
      rotate-server-certificates: true
EOF

    # Create specific patch for control plane with etcd configuration
    cat > "$CONFIG_DIR/controlplane-patch.yaml" << EOF
cluster:
  allowSchedulingOnControlPlanes: false
  etcd:
    advertisedSubnets:
      - 192.168.1.0/24
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12
machine:
  network:
    nameservers:
      - 192.168.1.3
      - 8.8.8.8
  install:
    disk: /dev/sda
    wipe: false
  kubelet:
    extraArgs:
      rotate-server-certificates: true
EOF

    # Apply patches to control plane config
    talosctl machineconfig patch "$CONFIG_DIR/controlplane.yaml" \
        --patch @"$CONFIG_DIR/controlplane-patch.yaml" \
        --output "$CONFIG_DIR/controlplane.yaml"
    
    # Apply patches to worker config  
    talosctl machineconfig patch "$CONFIG_DIR/worker.yaml" \
        --patch @"$CONFIG_DIR/patch.yaml" \
        --output "$CONFIG_DIR/worker.yaml"

    log "Base configurations generated and patched"
}

# Wait for node to be reachable
wait_for_node() {
    local node_ip=$1
    local max_attempts=15  # Reduced since we just need basic connectivity
    local attempt=1
    
    log "Waiting for node $node_ip to be reachable..."
    
    # First check basic network connectivity
    if ! ping -c 1 "$node_ip" &>/dev/null; then
        error "Node $node_ip is not reachable via ping"
        return 1
    fi
    
    log "Node $node_ip responds to ping, checking if Talos port is open..."
    
    while [ $attempt -le $max_attempts ]; do
        # Just check if port 50000 is open (Talos is running)
        if timeout 2 nc -z "$node_ip" 50000 2>/dev/null; then
            log "Node $node_ip has Talos running (port 50000 open)"
            return 0
        fi
        
        echo -n "."
        sleep 10
        ((attempt++))
    done
    
    error "Node $node_ip port 50000 not reachable after $max_attempts attempts"
    return 1
}

# Apply configuration to control plane nodes
configure_control_planes() {
    log "Configuring control plane nodes..."
    
    for ip in "${CONTROL_PLANE_IPS[@]}"; do
        log "Configuring control plane $ip..."
        wait_for_node "$ip"
        
        log "Applying configuration to control plane $ip..."
        if talosctl apply-config --insecure \
            --nodes "$ip" \
            --endpoints "$ip" \
            --file "$CONFIG_DIR/controlplane.yaml"; then
            log "Configuration applied successfully to $ip"
        else
            error "Failed to apply configuration to $ip"
            return 1
        fi
        
        log "Waiting for $ip to reboot and apply configuration..."
        sleep 30
    done
    
    log "All control planes configured"
}

# Apply configuration to worker nodes
configure_workers() {
    log "Configuring worker nodes..."
    
    for ip in "${WORKER_IPS[@]}"; do
        log "Configuring worker $ip..."
        wait_for_node "$ip"
        
        log "Applying configuration to worker $ip..."
        if talosctl apply-config --insecure \
            --nodes "$ip" \
            --endpoints "$ip" \
            --file "$CONFIG_DIR/worker.yaml"; then
            log "Configuration applied successfully to $ip"
        else
            error "Failed to apply configuration to $ip"
            return 1
        fi
        
        log "Waiting for $ip to reboot and apply configuration..."
        sleep 30
    done
    
    log "All workers configured"
}

# Bootstrap the cluster
bootstrap_cluster() {
    log "Bootstrapping etcd on first control plane..."
    
    # Wait a bit for the control plane to be ready
    sleep 30
    
    talosctl bootstrap \
        --nodes "${CONTROL_PLANE_IPS[0]}" \
        --endpoints "${CONTROL_PLANE_IPS[0]}" \
        --talosconfig "$CONFIG_DIR/talosconfig"
    
    log "Cluster bootstrapped"
}

# Wait for cluster to be ready
wait_for_cluster() {
    log "Waiting for cluster to be ready..."
    
    local max_attempts=60  # Reduced from 120
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Try different health checks
        if talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
           --nodes "${CONTROL_PLANE_IPS[0]}" \
           --endpoints "${CONTROL_PLANE_IPS[0]}" \
           health --wait-timeout=10s &>/dev/null; then
            log "Cluster is healthy"
            return 0
        fi
        
        # If health check fails, try to get more info
        if [ $((attempt % 10)) -eq 0 ]; then
            log "Health check failed, getting diagnostics (attempt $attempt/$max_attempts)..."
            
            # Check if etcd is running
            log "Checking etcd status..."
            talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
                --nodes "${CONTROL_PLANE_IPS[0]}" \
                --endpoints "${CONTROL_PLANE_IPS[0]}" \
                service etcd 2>/dev/null || log "etcd service check failed"
            
            # Check if kubelet is running
            log "Checking kubelet status..."
            talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
                --nodes "${CONTROL_PLANE_IPS[0]}" \
                --endpoints "${CONTROL_PLANE_IPS[0]}" \
                service kubelet 2>/dev/null || log "kubelet service check failed"
                
            # Check if we can reach the Kubernetes API
            log "Checking if Kubernetes API is accessible..."
            if talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
               --nodes "${CONTROL_PLANE_IPS[0]}" \
               --endpoints "${CONTROL_PLANE_IPS[0]}" \
               version 2>/dev/null; then
                log "Talos API is responding, checking Kubernetes API..."
                # Try to get kubeconfig and test it
                if talosctl kubeconfig \
                   --nodes "${CONTROL_PLANE_IPS[0]}" \
                   --endpoints "${CONTROL_PLANE_IPS[0]}" \
                   --talosconfig "$CONFIG_DIR/talosconfig" \
                   "$CONFIG_DIR/test-kubeconfig" 2>/dev/null; then
                    
                    if kubectl --kubeconfig "$CONFIG_DIR/test-kubeconfig" get nodes 2>/dev/null; then
                        log "Kubernetes API is responding!"
                        return 0
                    else
                        log "Kubernetes API not yet ready"
                    fi
                fi
            else
                log "Talos API not responding"
            fi
        fi
        
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    error "Cluster not ready after $max_attempts attempts"
    error "Final diagnostics:"
    
    # Final diagnostic dump
    log "=== Talos Version ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "${CONTROL_PLANE_IPS[0]}" \
        --endpoints "${CONTROL_PLANE_IPS[0]}" \
        version 2>&1 || echo "Failed to get version"
    
    log "=== Service Status ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "${CONTROL_PLANE_IPS[0]}" \
        --endpoints "${CONTROL_PLANE_IPS[0]}" \
        services 2>&1 || echo "Failed to get services"
    
    return 1
}

# Generate kubeconfig
generate_kubeconfig() {
    log "Generating kubeconfig..."
    
    talosctl kubeconfig \
        --nodes "${CONTROL_PLANE_IPS[0]}" \
        --endpoints "${CONTROL_PLANE_IPS[0]}" \
        --talosconfig "$CONFIG_DIR/talosconfig" \
        "$CONFIG_DIR/kubeconfig"
    
    # Update server address and context name
    sed -i "s/127.0.0.1/${CLUSTER_ENDPOINT}/g" "$CONFIG_DIR/kubeconfig"
    sed -i "s/admin@${CLUSTER_NAME}/${CLUSTER_NAME}/g" "$CONFIG_DIR/kubeconfig"
    sed -i "s/default/${CLUSTER_NAME}/g" "$CONFIG_DIR/kubeconfig"
    
    log "Kubeconfig generated at $CONFIG_DIR/kubeconfig"
}

# Update Vault with kubeconfig
update_vault() {
    if [ -n "$VAULT_TOKEN" ] && [ -f "../scripts/update_kubeconfig.py" ]; then
        log "Updating Vault with kubeconfig..."
        
        python3 ../scripts/update_kubeconfig.py \
            --cluster-name "$CLUSTER_NAME" \
            --kubeconfig-file "$CONFIG_DIR/kubeconfig" \
            --vault-addr "https://vault.fullstack.pw" \
            --vault-token "$VAULT_TOKEN" \
            --host-address "$CLUSTER_ENDPOINT"
    else
        warn "Skipping Vault update (missing VAULT_TOKEN or update script)"
    fi
}

# Display cluster info
show_cluster_info() {
    log "Cluster setup complete!"
    echo
    echo "Cluster Information:"
    echo "  Name: $CLUSTER_NAME"
    echo "  Endpoint: https://${CLUSTER_ENDPOINT}:6443"
    echo "  Control Planes: ${CONTROL_PLANE_IPS[*]}"
    echo "  Workers: ${WORKER_IPS[*]}"
    echo
    echo "Configuration files:"
    echo "  Talos config: $CONFIG_DIR/talosconfig"
    echo "  Kubeconfig: $CONFIG_DIR/kubeconfig"
    echo
    echo "Useful commands:"
    echo "  talosctl --talosconfig $CONFIG_DIR/talosconfig dashboard --nodes ${CONTROL_PLANE_IPS[0]}"
    echo "  kubectl --kubeconfig $CONFIG_DIR/kubeconfig get nodes"
}

# Debug function to check all nodes
debug_nodes() {
    log "Debugging node connectivity..."
    
    local all_ips=("${CONTROL_PLANE_IPS[@]}" "${WORKER_IPS[@]}")
    
    for ip in "${all_ips[@]}"; do
        echo "Node $ip:"
        echo "  Ping: $(ping -c 1 $ip >/dev/null 2>&1 && echo 'OK' || echo 'FAILED')"
        echo "  Port 50000: $(timeout 2 nc -z $ip 50000 >/dev/null 2>&1 && echo 'OPEN' || echo 'CLOSED')"
        echo "  Talos API: $(timeout 5 talosctl --nodes $ip --insecure version >/dev/null 2>&1 && echo 'OK' || echo 'FAILED')"
        echo ""
    done
}

# Clean reset function
reset_node() {
    local node_ip=$1
    log "Resetting node $node_ip to factory defaults..."
    
    # Reset without waiting (can't use --wait with --insecure)
    talosctl reset --insecure \
        --nodes "$node_ip" \
        --endpoints "$node_ip" \
        --graceful=false \
        --reboot=false || warn "Reset failed for $node_ip"
    
    # Then manually trigger reboot
    log "Triggering reboot for $node_ip..."
    talosctl reboot --insecure \
        --nodes "$node_ip" \
        --endpoints "$node_ip" || warn "Reboot failed for $node_ip"
}

# Reset all nodes function
reset_all_nodes() {
    log "Resetting all nodes..."
    
    local all_ips=("${CONTROL_PLANE_IPS[@]}" "${WORKER_IPS[@]}")
    
    for ip in "${all_ips[@]}"; do
        if timeout 2 nc -z "$ip" 50000 2>/dev/null; then
            reset_node "$ip"
        else
            warn "Node $ip not reachable, skipping reset"
        fi
    done
    
    log "Waiting for nodes to reboot..."
    sleep 60
}

# Manual diagnostics function
diagnose_cluster() {
    log "Running cluster diagnostics..."
    
    if [ ! -f "$CONFIG_DIR/talosconfig" ]; then
        error "No talosconfig found. Run bootstrap first."
        return 1
    fi
    
    local first_cp="${CONTROL_PLANE_IPS[0]}"
    
    echo "=== Cluster Diagnostics ==="
    echo "Using control plane: $first_cp"
    echo ""
    
    echo "=== Talos Version ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "$first_cp" \
        --endpoints "$first_cp" \
        version
    echo ""
    
    echo "=== Service Status ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "$first_cp" \
        --endpoints "$first_cp" \
        services
    echo ""
    
    echo "=== etcd Logs ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "$first_cp" \
        --endpoints "$first_cp" \
        logs --tail=20 etcd
    echo ""
    
    echo "=== System Logs (last 20 lines) ==="
    talosctl --talosconfig "$CONFIG_DIR/talosconfig" \
        --nodes "$first_cp" \
        --endpoints "$first_cp" \
        logs --tail=20 kubelet
    echo ""
    
    echo "=== Trying to get kubeconfig ==="
    if talosctl kubeconfig \
       --nodes "$first_cp" \
       --endpoints "$first_cp" \
       --talosconfig "$CONFIG_DIR/talosconfig" \
       "$CONFIG_DIR/diagnostic-kubeconfig" 2>/dev/null; then
        
        echo "Kubeconfig obtained, testing Kubernetes API..."
        kubectl --kubeconfig "$CONFIG_DIR/diagnostic-kubeconfig" get nodes -o wide
        echo ""
        kubectl --kubeconfig "$CONFIG_DIR/diagnostic-kubeconfig" get pods -A
    else
        echo "Failed to get kubeconfig"
    fi
}


# Main execution
main() {
    log "Starting Talos cluster bootstrap..."
    
    install_talosctl
    generate_configs
    configure_control_planes
    configure_workers
    bootstrap_cluster
    wait_for_cluster
    generate_kubeconfig
    update_vault
    show_cluster_info
}


# Handle command line arguments
case "${1:-main}" in
    "reset")
        reset_all_nodes
        ;;
    "reset-node")
        if [ -z "$2" ]; then
            error "Usage: $0 reset-node <ip>"
            exit 1
        fi
        reset_node "$2"
        ;;
    "diagnose")
        diagnose_cluster
        ;;
    "debug")
        debug_nodes
        ;;
    "configs")
        install_talosctl
        generate_configs
        ;;
    "control-planes")
        configure_control_planes
        ;;
    "workers")
        configure_workers
        ;;
    "bootstrap")
        bootstrap_cluster
        ;;
    "kubeconfig")
        generate_kubeconfig
        update_vault
        ;;
    *)
        main
        ;;
esac
