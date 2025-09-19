#!/bin/bash
# Script to create a new secret file with the correct structure

set -e

# Default values
DEFAULT_ENV="common"
DEFAULT_PATH="cluster-secret-store/secrets"

# Check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <secret-name> <secret-value> [environment] [path]"
  echo "Example: $0 API_KEY \"my-api-key-12345\" common cluster-secret-store/secrets"
  echo "Default environment: $DEFAULT_ENV"
  echo "Default path: $DEFAULT_PATH"
  exit 1
fi

SECRET_NAME=$1
SECRET_VALUE=$2
ENVIRONMENT=${3:-$DEFAULT_ENV}
SECRET_PATH=${4:-$DEFAULT_PATH}

# Create directory structure
FULL_PATH="secrets/$ENVIRONMENT/$SECRET_PATH"
mkdir -p "$FULL_PATH"

# Create the file
SECRET_FILE="$FULL_PATH/$SECRET_NAME.yaml"

# Check if file already exists
if [ -f "$SECRET_FILE" ]; then
  echo "Warning: Secret file already exists: $SECRET_FILE"
  read -p "Do you want to overwrite it? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Create YAML structure based on path parts
echo "Creating secret file: $SECRET_FILE"

# Split path by '/' and build the nested YAML structure
IFS='/' read -ra PATH_PARTS <<< "$SECRET_PATH"

# Start with the basic structure
echo "vault:" > "$SECRET_FILE"
echo "  kv:" >> "$SECRET_FILE"

# Add indentation for each path part
INDENT="    "
for part in "${PATH_PARTS[@]}"; do
  echo "${INDENT}${part}:" >> "$SECRET_FILE"
  INDENT="${INDENT}  "
done

# Add the secret with proper nesting structure
echo "${INDENT}${SECRET_NAME}:" >> "$SECRET_FILE"
echo "${INDENT}  ${SECRET_NAME}: \"${SECRET_VALUE}\"" >> "$SECRET_FILE"

echo "Secret file created. Now encrypting..."

# Encrypt the file
sops --encrypt --in-place "$SECRET_FILE"

echo "Secret created and encrypted: $SECRET_FILE"