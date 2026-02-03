#!/bin/bash
set -e

OPERATION="$1"
CLUSTER_NAME="$2"
KUBECONFIG_FILE="$3"
VAULT_PATH="${VAULT_PATH:-kv/cluster-secret-store/secrets}"

if [ -z "$OPERATION" ] || [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <add|remove|get> <cluster-name> [kubeconfig-file]"
  exit 1
fi

yaml_to_json() {
  python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)'
}

json_to_yaml() {
  python3 -c 'import sys, yaml, json; yaml.dump(json.load(sys.stdin), sys.stdout, default_flow_style=False, sort_keys=False)'
}

merge_kubeconfig() {
  local EXISTING_KUBECONFIG="$1"
  local NEW_KUBECONFIG="$2"
  local CLUSTER_NAME="$3"

  local TMP_EXISTING=$(mktemp)
  local TMP_NEW=$(mktemp)
  local TMP_MERGED=$(mktemp)

  echo "$EXISTING_KUBECONFIG" | yaml_to_json > "$TMP_EXISTING"
  echo "$NEW_KUBECONFIG" | yaml_to_json > "$TMP_NEW"

  # Remove existing cluster entries
  jq --arg cluster "$CLUSTER_NAME" '
    .clusters |= map(select(.name != $cluster)) |
    .users |= map(select(.name != $cluster)) |
    .contexts |= map(select(.name != $cluster))
  ' "$TMP_EXISTING" > "$TMP_MERGED"

  # Add new entries
  NEW_CLUSTER=$(jq --arg cluster "$CLUSTER_NAME" '.clusters[0] | .name = $cluster' "$TMP_NEW")
  NEW_USER=$(jq --arg cluster "$CLUSTER_NAME" '.users[0] | .name = $cluster' "$TMP_NEW")
  NEW_CONTEXT=$(jq --arg cluster "$CLUSTER_NAME" '
    .contexts[0] |
    .name = $cluster |
    .context.cluster = $cluster |
    .context.user = $cluster
  ' "$TMP_NEW")

  jq --argjson new_cluster "$NEW_CLUSTER" \
     --argjson new_user "$NEW_USER" \
     --argjson new_context "$NEW_CONTEXT" \
     --arg cluster "$CLUSTER_NAME" '
    .clusters += [$new_cluster] |
    .users += [$new_user] |
    .contexts += [$new_context] |
    ."current-context" = $cluster
  ' "$TMP_MERGED" | json_to_yaml

  rm -f "$TMP_EXISTING" "$TMP_NEW" "$TMP_MERGED"
}

delete_cluster_from_kubeconfig() {
  local EXISTING_KUBECONFIG="$1"
  local CLUSTER_NAME="$2"

  local TMP_EXISTING=$(mktemp)
  echo "$EXISTING_KUBECONFIG" | yaml_to_json > "$TMP_EXISTING"

  jq --arg cluster "$CLUSTER_NAME" '
    .clusters |= map(select(.name != $cluster)) |
    .users |= map(select(.name != $cluster)) |
    .contexts |= map(select(.name != $cluster))
  ' "$TMP_EXISTING" > "$TMP_EXISTING.filtered"

  CURRENT_CONTEXT=$(jq -r '."current-context" // ""' "$TMP_EXISTING.filtered")
  if [ "$CURRENT_CONTEXT" == "$CLUSTER_NAME" ]; then
    FIRST_CONTEXT=$(jq -r '.contexts[0].name // ""' "$TMP_EXISTING.filtered")
    if [ -n "$FIRST_CONTEXT" ] && [ "$FIRST_CONTEXT" != "null" ]; then
      jq --arg first "$FIRST_CONTEXT" '."current-context" = $first' "$TMP_EXISTING.filtered" | json_to_yaml
    else
      jq 'del(."current-context")' "$TMP_EXISTING.filtered" | json_to_yaml
    fi
  else
    cat "$TMP_EXISTING.filtered" | json_to_yaml
  fi

  rm -f "$TMP_EXISTING" "$TMP_EXISTING.filtered"
}

case "$OPERATION" in
  add)
    if [ -z "$KUBECONFIG_FILE" ] || [ ! -f "$KUBECONFIG_FILE" ]; then
      echo "Error: Kubeconfig file required for add operation"
      exit 1
    fi

    NEW_KUBECONFIG=$(cat "$KUBECONFIG_FILE")

    # Get existing PR_KUBECONFIG from Vault (or create empty)
    set +e
    EXISTING_KUBECONFIG=$(vault kv get -field=PR_KUBECONFIG "$VAULT_PATH" 2>/dev/null)
    if [ $? -ne 0 ]; then
      # Create empty kubeconfig if it doesn't exist
      EXISTING_KUBECONFIG="apiVersion: v1
kind: Config
clusters: []
contexts: []
users: []
current-context: \"\""
    fi
    set -e

    MERGED_KUBECONFIG=$(merge_kubeconfig "$EXISTING_KUBECONFIG" "$NEW_KUBECONFIG" "$CLUSTER_NAME")

    # Write back to Vault
    echo "$MERGED_KUBECONFIG" | vault kv put "$VAULT_PATH" PR_KUBECONFIG=-

    echo "Added $CLUSTER_NAME to PR_KUBECONFIG in Vault"
    ;;

  remove)
    EXISTING_KUBECONFIG=$(vault kv get -field=PR_KUBECONFIG "$VAULT_PATH")
    UPDATED_KUBECONFIG=$(delete_cluster_from_kubeconfig "$EXISTING_KUBECONFIG" "$CLUSTER_NAME")

    # Write back to Vault
    echo "$UPDATED_KUBECONFIG" | vault kv put "$VAULT_PATH" PR_KUBECONFIG=-

    echo "Removed $CLUSTER_NAME from PR_KUBECONFIG in Vault"
    ;;

  get)
    vault kv get -field=PR_KUBECONFIG "$VAULT_PATH"
    ;;

  *)
    echo "Invalid operation: $OPERATION"
    exit 1
    ;;
esac
