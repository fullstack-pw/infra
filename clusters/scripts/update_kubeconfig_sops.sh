#!/bin/bash

set -e

CLUSTER_NAME="$1"
NAMESPACE="$2"
MANAGEMENT_CONTEXT="$3"
OPERATION="${4:-upsert}"

if [ -z "$CLUSTER_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$MANAGEMENT_CONTEXT" ]; then
  echo "Usage: $0 <cluster-name> <namespace> <management-context> [upsert|delete]"
  exit 1
fi

SOPS_FILE="secrets/common/cluster-secret-store/secrets/KUBECONFIG.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOPS_CONFIG="$SCRIPT_DIR/.sops.yaml"

if [ ! -f "$SOPS_FILE" ]; then
  echo "Error: SOPS file not found: $SOPS_FILE"
  exit 1
fi

if [ ! -f "$SOPS_CONFIG" ]; then
  echo "Error: SOPS config not found: $SOPS_CONFIG"
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

  jq --arg cluster "$CLUSTER_NAME" '
    .clusters |= map(if .name == $cluster then .name = "TO_DELETE" else . end) |
    .users |= map(if .name == $cluster then .name = "TO_DELETE" else . end) |
    .contexts |= map(if .name == $cluster then .name = "TO_DELETE" else . end)
  ' "$TMP_EXISTING" > "$TMP_MERGED"

  jq '
    .clusters |= map(select(.name != "TO_DELETE")) |
    .users |= map(select(.name != "TO_DELETE")) |
    .contexts |= map(select(.name != "TO_DELETE"))
  ' "$TMP_MERGED" > "$TMP_MERGED.clean"

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
  ' "$TMP_MERGED.clean" | json_to_yaml

  rm -f "$TMP_EXISTING" "$TMP_NEW" "$TMP_MERGED" "$TMP_MERGED.clean"
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

if [ "$OPERATION" == "upsert" ]; then
  set +e
  KUBECONFIG_B64=$(kubectl --context "$MANAGEMENT_CONTEXT" \
    get secret "${CLUSTER_NAME}-kubeconfig" \
    -n "$NAMESPACE" \
    -o jsonpath='{.data.value}' 2>&1)
  EXIT_CODE=$?
  set -e

  if [ $EXIT_CODE -ne 0 ]; then
    if echo "$KUBECONFIG_B64" | grep -q "NotFound\|not found"; then
      echo "Cluster API secret not found for $CLUSTER_NAME"
      exit 0
    else
      echo "Failed to extract kubeconfig: $KUBECONFIG_B64"
      exit 1
    fi
  fi

  if [ -z "$KUBECONFIG_B64" ]; then
    echo "Kubeconfig secret exists but has no data"
    exit 1
  fi

  NEW_KUBECONFIG=$(echo "$KUBECONFIG_B64" | base64 -d)

  TMP_SOPS_JSON=$(mktemp)
  
  sops -d --output-type=json "$SOPS_FILE" > "$TMP_SOPS_JSON"

  EXISTING_KUBECONFIG=$(jq -r '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG' "$TMP_SOPS_JSON")
  rm -f "$TMP_SOPS_JSON"

  MERGED_KUBECONFIG=$(merge_kubeconfig "$EXISTING_KUBECONFIG" "$NEW_KUBECONFIG" "$CLUSTER_NAME")

  TMP_DECRYPTED="${SOPS_FILE%.yaml}.tmp.yaml"
  TMP_JSON=$(mktemp)

  sops -d "$SOPS_FILE" > "$TMP_DECRYPTED"
  yaml_to_json < "$TMP_DECRYPTED" > "$TMP_JSON"

  TMP_MERGED=$(mktemp)
  echo "$MERGED_KUBECONFIG" > "$TMP_MERGED"
  MERGED_KUBECONFIG_STR=$(cat "$TMP_MERGED")

  jq --arg kubeconfig "$MERGED_KUBECONFIG_STR" \
    '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG = $kubeconfig' \
    "$TMP_JSON" | json_to_yaml > "$TMP_DECRYPTED"

  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.sops/keys/sops-key.txt}" \
    sops --encrypt --in-place "$TMP_DECRYPTED"

  mv "$TMP_DECRYPTED" "$SOPS_FILE"

  rm -f "$TMP_JSON" "$TMP_MERGED"

  echo "Updated SOPS file with kubeconfig for cluster: $CLUSTER_NAME"

elif [ "$OPERATION" == "delete" ]; then
  TMP_SOPS_JSON=$(mktemp)
  sops -d --output-type=json "$SOPS_FILE" > "$TMP_SOPS_JSON"

  EXISTING_KUBECONFIG=$(jq -r '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG' "$TMP_SOPS_JSON")
  rm -f "$TMP_SOPS_JSON"

  UPDATED_KUBECONFIG=$(delete_cluster_from_kubeconfig "$EXISTING_KUBECONFIG" "$CLUSTER_NAME")

  TMP_DECRYPTED="${SOPS_FILE%.yaml}.tmp.yaml"
  TMP_JSON=$(mktemp)

  sops -d "$SOPS_FILE" > "$TMP_DECRYPTED"
  yaml_to_json < "$TMP_DECRYPTED" > "$TMP_JSON"

  TMP_UPDATED_KC=$(mktemp)
  echo "$UPDATED_KUBECONFIG" > "$TMP_UPDATED_KC"
  UPDATED_KUBECONFIG_STR=$(cat "$TMP_UPDATED_KC")

  jq --arg kubeconfig "$UPDATED_KUBECONFIG_STR" \
    '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG = $kubeconfig' \
    "$TMP_JSON" | json_to_yaml > "$TMP_DECRYPTED"

  SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.sops/keys/sops-key.txt}" \
    sops --encrypt --in-place "$TMP_DECRYPTED"

  mv "$TMP_DECRYPTED" "$SOPS_FILE"

  rm -f "$TMP_JSON" "$TMP_UPDATED_KC"

  echo "Removed kubeconfig for cluster: $CLUSTER_NAME from SOPS file"

else
  echo "Invalid operation: $OPERATION"
  exit 1
fi
