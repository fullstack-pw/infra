#!/bin/bash
# Script to encrypt all YAML files in the secrets directory with SOPS

set -e

# Check if SOPS_AGE_KEY_FILE is set
if [ -z "$SOPS_AGE_KEY_FILE" ]; then
  echo "Error: SOPS_AGE_KEY_FILE environment variable is not set."
  echo "Please set it to the path of your age key file."
  exit 1
fi

# Check if the key file exists
if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
  echo "Error: Age key file not found at $SOPS_AGE_KEY_FILE"
  exit 1
fi

# Check if .sops.yaml exists
if [ ! -f ".sops.yaml" ]; then
  echo "Error: .sops.yaml configuration file not found in the current directory."
  exit 1
fi

# Function to encrypt all YAML files in a directory
encrypt_directory() {
  local dir=$1
  echo "Processing directory: $dir"
  
  # Find all YAML files that are not already encrypted
  # (encrypted files have a 'sops:' key)
  find "$dir" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) | while read -r file; do
    if ! grep -q "sops:" "$file"; then
      echo "Encrypting: $file"
      sops --encrypt --in-place "$file"
    else
      echo "Already encrypted, skipping: $file"
    fi
  done
}

# Main script
echo "Starting encryption of secrets..."

# Check if the secrets directory exists
if [ ! -d "secrets" ]; then
  echo "Error: 'secrets' directory not found. Please run the extraction script first."
  exit 1
fi

# Process each environment
for env_dir in secrets/*; do
  if [ -d "$env_dir" ]; then
    encrypt_directory "$env_dir"
  fi
done

echo "Encryption complete!"