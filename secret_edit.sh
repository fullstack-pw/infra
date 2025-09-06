#!/bin/bash
# Script to safely edit an encrypted secret
EDITOR="code --wait --new-window --disable-extensions"
set -e

# Check arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <secret-file-path>"
  echo "Example: $0 secrets/common/vault/cluster-secret-store/secrets/GITHUB_PAT.yaml"
  exit 1
fi

SECRET_FILE=$1

# Check if the file exists
if [ ! -f "$SECRET_FILE" ]; then
  echo "Error: Secret file not found: $SECRET_FILE"
  exit 1
fi

# Check if it's encrypted
if ! grep -q "sops:" "$SECRET_FILE"; then
  echo "Warning: This file doesn't appear to be encrypted with SOPS."
  read -p "Do you want to encrypt it after editing? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Open the file for editing
    vim "$SECRET_FILE"
    
    # Encrypt the file
    echo "Encrypting the file..."
    sops --encrypt --in-place "$SECRET_FILE"
    echo "File encrypted and saved."
  else
    # Just open for editing without encrypting
    vim "$SECRET_FILE"
  fi
else
  # File is already encrypted, use SOPS to edit
  sops "$SECRET_FILE"
fi