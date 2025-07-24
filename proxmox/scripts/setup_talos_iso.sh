#!/bin/bash
# proxmox/scripts/setup_talos_iso.sh
# Script to download Talos ISO for Proxmox

set -e

TALOS_VERSION="v1.10.3"
PROXMOX_HOST="192.168.1.248"
ISO_STORAGE="local"
ISO_NAME="metal-amd64.iso"
TALOS_ISO_NAME="talos-${TALOS_VERSION}-metal-amd64.iso"
DOWNLOAD_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/metal-amd64.iso"

echo "Setting up Talos ISO for Proxmox..."

# Function to check if ISO exists on Proxmox node
check_iso_exists() {
    if ssh root@${PROXMOX_HOST} "ls /var/lib/vz/template/iso/ | grep -q ${TALOS_ISO_NAME}"; then
        echo "ISO ${TALOS_ISO_NAME} already exists in Proxmox"
        return 0
    else
        return 1
    fi
}

# Download and upload ISO to Proxmox
download_and_upload_iso() {
    echo "Downloading Talos ISO version ${TALOS_VERSION}..."
    
    # Download to temporary location
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "Downloading from: $DOWNLOAD_URL"
    wget -O "$TALOS_ISO_NAME" "$DOWNLOAD_URL"
    
    # Verify download
    if [ ! -f "$TALOS_ISO_NAME" ] || [ ! -s "$TALOS_ISO_NAME" ]; then
        echo "Error: Failed to download ISO or file is empty"
        ls -la
        exit 1
    fi
    
    echo "Downloaded $(du -h "$TALOS_ISO_NAME" | cut -f1) ISO"
    echo "Uploading ISO to Proxmox storage..."
    
    # Upload to Proxmox storage
    scp "$TALOS_ISO_NAME" root@${PROXMOX_HOST}:/var/lib/vz/template/iso/
    
    echo "Verifying upload..."
    if ssh root@${PROXMOX_HOST} "ls -la /var/lib/vz/template/iso/${TALOS_ISO_NAME}"; then
        echo "ISO uploaded successfully"
    else
        echo "Error: ISO upload failed"
        exit 1
    fi
    
    # Cleanup
    cd - && rm -rf "$TEMP_DIR"
}

# Main execution
if ! check_iso_exists; then
    download_and_upload_iso
else
    echo "Talos ISO already available"
fi

echo "Talos ISO setup complete"
echo "ISO name in Proxmox: ${TALOS_ISO_NAME}"
echo ""
echo "Next steps:"
echo "1. Update your VM configs to use: local:iso/${TALOS_ISO_NAME}"
echo "2. Run: terraform apply in proxmox/ to create VMs"
echo "3. Start the VMs (they will boot from Talos ISO)"
echo "4. Run: ./scripts/bootstrap_talos_cluster.sh to configure Talos"