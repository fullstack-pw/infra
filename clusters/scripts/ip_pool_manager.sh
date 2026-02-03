#!/usr/bin/env bash

# IP Pool Manager for Ephemeral Clusters
# Manages IP allocation from pool 192.168.1.140-149 (10 IPs)
# Tracks allocations in Vault at kv/ephemeral-clusters/ip-allocations

set -euo pipefail

# Configuration
VAULT_PATH="kv/ephemeral-clusters/ip-allocations"
IP_POOL_START=140
IP_POOL_END=149
IP_PREFIX="192.168.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if VAULT_ADDR and VAULT_TOKEN are set
if [[ -z "${VAULT_ADDR:-}" ]] || [[ -z "${VAULT_TOKEN:-}" ]]; then
    echo -e "${RED}Error: VAULT_ADDR and VAULT_TOKEN environment variables must be set${NC}"
    exit 1
fi

# Function to get current allocations from Vault
get_allocations() {
    vault kv get -format=json "$VAULT_PATH" 2>/dev/null | jq -r '.data.data // {}' || echo '{}'
}

# Function to save allocations to Vault using CAS (Check-And-Set)
save_allocations() {
    local allocations="$1"
    local version="${2:-0}"

    # Send allocations directly - Vault KV v2 will wrap it in {data: ...} automatically
    if [[ "$version" -eq 0 ]]; then
        # First write (no version check)
        echo "$allocations" | vault kv put "$VAULT_PATH" - > /dev/null
    else
        # CAS write with version check
        echo "$allocations" | vault kv put -cas="$version" "$VAULT_PATH" - > /dev/null
    fi
}

# Function to get current version from Vault
get_version() {
    vault kv get -format=json "$VAULT_PATH" 2>/dev/null | jq -r '.data.metadata.version // 0'
}

# Function to allocate an IP for a cluster
allocate_ip() {
    local cluster_name="$1"

    if [[ -z "$cluster_name" ]]; then
        echo -e "${RED}Error: Cluster name is required${NC}"
        echo "Usage: $0 allocate <cluster-name>"
        exit 1
    fi

    # Retry loop for CAS conflicts
    local max_retries=5
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        # Get current allocations and version
        local allocations=$(get_allocations)
        local version=$(get_version)

        # Check if cluster already has an IP
        local existing_ip=$(echo "$allocations" | jq -r --arg cluster "$cluster_name" 'to_entries[] | select(.value == $cluster) | .key')
        if [[ -n "$existing_ip" ]]; then
            echo -e "${YELLOW}Cluster $cluster_name already has IP: $existing_ip${NC}"
            echo "$existing_ip"
            return 0
        fi

        # Find first available IP pair (each cluster needs 2 consecutive IPs: VIP and node)
        local ip_found=""
        for ip_suffix in $(seq $IP_POOL_START 2 $IP_POOL_END); do
            local vip="$IP_PREFIX.$ip_suffix"
            local node_ip="$IP_PREFIX.$((ip_suffix + 1))"
            local vip_allocated=$(echo "$allocations" | jq -r --arg ip "$vip" '.[$ip] // empty')
            local node_allocated=$(echo "$allocations" | jq -r --arg ip "$node_ip" '.[$ip] // empty')

            # Check if both IPs are available
            if [[ -z "$vip_allocated" ]] && [[ -z "$node_allocated" ]]; then
                ip_found="$vip"
                break
            fi
        done

        if [[ -z "$ip_found" ]]; then
            echo -e "${RED}Error: IP pool exhausted. Maximum 5 concurrent ephemeral clusters.${NC}"
            echo -e "${YELLOW}Active allocations:${NC}"
            echo "$allocations" | jq -r 'to_entries[] | "\(.key) -> \(.value)"'
            echo ""
            echo -e "${YELLOW}Please close old PRs or wait for auto-cleanup to free IPs.${NC}"
            echo -e "${YELLOW}Note: Each cluster requires 2 consecutive IPs (VIP + node).${NC}"
            exit 1
        fi

        # Calculate node IP
        local ip_suffix=$(echo "$ip_found" | cut -d'.' -f4)
        local node_ip="$IP_PREFIX.$((ip_suffix + 1))"

        # Add new allocations for both VIP and node
        local new_allocations=$(echo "$allocations" | jq \
            --arg vip "$ip_found" \
            --arg node "$node_ip" \
            --arg cluster "$cluster_name" \
            '. + {($vip): $cluster, ($node): $cluster}')

        # Try to save with CAS
        if save_allocations "$new_allocations" "$version" 2>/dev/null; then
            echo -e "${GREEN}Successfully allocated IP $ip_found to cluster $cluster_name${NC}" >&2
            echo "$ip_found"
            return 0
        else
            # CAS conflict, retry
            retry=$((retry + 1))
            echo -e "${YELLOW}CAS conflict, retrying ($retry/$max_retries)...${NC}" >&2
            sleep 1
        fi
    done

    echo -e "${RED}Error: Failed to allocate IP after $max_retries retries (concurrent allocation conflict)${NC}"
    exit 1
}

# Function to release an IP from a cluster
release_ip() {
    local cluster_name="$1"

    if [[ -z "$cluster_name" ]]; then
        echo -e "${RED}Error: Cluster name is required${NC}"
        echo "Usage: $0 release <cluster-name>"
        exit 1
    fi

    # Retry loop for CAS conflicts
    local max_retries=5
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        # Get current allocations and version
        local allocations=$(get_allocations)
        local version=$(get_version)

        # Find all IPs for this cluster (should be 2: VIP and node)
        local ips_to_release=$(echo "$allocations" | jq -r --arg cluster "$cluster_name" 'to_entries[] | select(.value == $cluster) | .key')

        if [[ -z "$ips_to_release" ]]; then
            echo -e "${YELLOW}Warning: No IP allocation found for cluster $cluster_name${NC}"
            return 0
        fi

        # Remove all allocations for this cluster
        local new_allocations="$allocations"
        for ip in $ips_to_release; do
            new_allocations=$(echo "$new_allocations" | jq --arg ip "$ip" 'del(.[$ip])')
        done

        # Try to save with CAS
        if save_allocations "$new_allocations" "$version" 2>/dev/null; then
            echo -e "${GREEN}Successfully released IP $ip_to_release from cluster $cluster_name${NC}"
            echo "$ip_to_release"
            return 0
        else
            # CAS conflict, retry
            retry=$((retry + 1))
            echo -e "${YELLOW}CAS conflict, retrying ($retry/$max_retries)...${NC}" >&2
            sleep 1
        fi
    done

    echo -e "${RED}Error: Failed to release IP after $max_retries retries (concurrent modification conflict)${NC}"
    exit 1
}

# Function to list all current allocations
list_allocations() {
    local allocations=$(get_allocations)
    local count=$(echo "$allocations" | jq 'length')

    echo -e "${GREEN}Current IP Allocations ($count/10 used):${NC}"
    echo "$allocations" | jq -r 'to_entries[] | "\(.key) -> \(.value)"' | sort

    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}No IPs currently allocated${NC}"
    fi

    # Show available IPs
    echo -e "\n${GREEN}Available IPs:${NC}"
    for ip_suffix in $(seq $IP_POOL_START $IP_POOL_END); do
        local ip="$IP_PREFIX.$ip_suffix"
        local allocated=$(echo "$allocations" | jq -r --arg ip "$ip" '.[$ip] // empty')

        if [[ -z "$allocated" ]]; then
            echo "$ip"
        fi
    done
}

# Function to check capacity
check_capacity() {
    local allocations=$(get_allocations)
    local count=$(echo "$allocations" | jq 'length')
    # Each cluster uses 2 IPs, so max clusters = 10 IPs / 2 = 5 clusters
    # Available IPs = 10 - used IPs
    # Available clusters = available IPs / 2
    local available_ips=$((10 - count))
    local available_clusters=$((available_ips / 2))

    echo "$available_clusters"

    if [[ $count -ge 10 ]]; then
        return 1  # At capacity
    else
        return 0  # Has capacity
    fi
}

# Main command dispatcher
case "${1:-}" in
    allocate)
        allocate_ip "${2:-}"
        ;;
    release)
        release_ip "${2:-}"
        ;;
    list)
        list_allocations
        ;;
    check-capacity)
        available=$(check_capacity)
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Capacity available: $available slots free${NC}"
            exit 0
        else
            echo -e "${RED}At capacity: 0 slots free${NC}"
            exit 1
        fi
        ;;
    *)
        echo "IP Pool Manager for Ephemeral Clusters"
        echo ""
        echo "Usage: $0 <command> [arguments]"
        echo ""
        echo "Commands:"
        echo "  allocate <cluster-name>    Allocate an IP from the pool (192.168.1.140-149)"
        echo "  release <cluster-name>     Release an IP back to the pool"
        echo "  list                       List all current IP allocations"
        echo "  check-capacity             Check if pool has available IPs"
        echo ""
        echo "Environment Variables:"
        echo "  VAULT_ADDR                 Vault server address (required)"
        echo "  VAULT_TOKEN                Vault authentication token (required)"
        echo ""
        echo "Examples:"
        echo "  $0 allocate pr-cksbackend-42"
        echo "  $0 release pr-cksbackend-42"
        echo "  $0 list"
        echo "  $0 check-capacity"
        exit 1
        ;;
esac
