#!/bin/bash
# Script to view a decrypted secret

set -e

# Check arguments
if [ $# -lt 1 ]; then
  echo "Usage: $0 <secret-file-path> [<json-path>]"
  echo "Example: $0 secrets/dev/vault/cluster-secret-store/secrets/KUBECONFIG.yaml"
  echo "Example with JSON path: $0 secrets/dev/vault/cluster-secret-store/secrets.yaml .vault.kv.cluster-secret-store.secrets.GITHUB_PAT"
  exit 1
fi

SECRET_FILE=$1
JSON_PATH=$2

# Check if the file exists
if [ ! -f "$SECRET_FILE" ]; then
  echo "Error: Secret file not found: $SECRET_FILE"
  exit 1
fi

# If a JSON path is provided, use it to extract a specific value
if [ -n "$JSON_PATH" ]; then
  if [[ "$SECRET_FILE" == *.yaml ]] || [[ "$SECRET_FILE" == *.yml ]]; then
    # For YAML files, convert to JSON first
    sops --decrypt "$SECRET_FILE" | yq -o=json | jq -r "$JSON_PATH"
  else
    # For JSON files, use jq directly
    sops --decrypt "$SECRET_FILE" | jq -r "$JSON_PATH"
  fi
else
  # Otherwise, show the entire decrypted file
  sops --decrypt "$SECRET_FILE"
fi