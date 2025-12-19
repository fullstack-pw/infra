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

if [ ! -f "$SOPS_FILE" ]; then
  echo "Error: SOPS file not found: $SOPS_FILE"
  exit 1
fi

merge_kubeconfig() {
  local EXISTING_KUBECONFIG="$1"
  local NEW_KUBECONFIG="$2"
  local CLUSTER_NAME="$3"

  local TMP_EXISTING=$(mktemp)
  local TMP_NEW=$(mktemp)
  local TMP_MERGED=$(mktemp)

  echo "$EXISTING_KUBECONFIG" > "$TMP_EXISTING"
  echo "$NEW_KUBECONFIG" > "$TMP_NEW"

  cp "$TMP_EXISTING" "$TMP_MERGED"

  yq eval "
    .clusters[] |= (select(.name == \"$CLUSTER_NAME\") | .name = \"TO_DELETE\") |
    .users[] |= (select(.name == \"$CLUSTER_NAME\") | .name = \"TO_DELETE\") |
    .contexts[] |= (select(.name == \"$CLUSTER_NAME\") | .name = \"TO_DELETE\")
  " -i "$TMP_MERGED"

  yq eval "del(.clusters[] | select(.name == \"TO_DELETE\"))" -i "$TMP_MERGED"
  yq eval "del(.users[] | select(.name == \"TO_DELETE\"))" -i "$TMP_MERGED"
  yq eval "del(.contexts[] | select(.name == \"TO_DELETE\"))" -i "$TMP_MERGED"

  NEW_CLUSTER=$(yq eval '.clusters[0]' "$TMP_NEW")
  NEW_USER=$(yq eval '.users[0]' "$TMP_NEW")
  NEW_CONTEXT=$(yq eval '.contexts[0]' "$TMP_NEW")

  NORMALIZED_CLUSTER=$(echo "$NEW_CLUSTER" | yq eval ".name = \"$CLUSTER_NAME\"" -)
  NORMALIZED_USER=$(echo "$NEW_USER" | yq eval ".name = \"$CLUSTER_NAME\"" -)
  NORMALIZED_CONTEXT=$(echo "$NEW_CONTEXT" | yq eval ".name = \"$CLUSTER_NAME\" | .context.cluster = \"$CLUSTER_NAME\" | .context.user = \"$CLUSTER_NAME\"" -)

  yq eval ".clusters += [$NORMALIZED_CLUSTER]" -i "$TMP_MERGED"
  yq eval ".users += [$NORMALIZED_USER]" -i "$TMP_MERGED"
  yq eval ".contexts += [$NORMALIZED_CONTEXT]" -i "$TMP_MERGED"

  yq eval ".current-context = \"$CLUSTER_NAME\"" -i "$TMP_MERGED"

  cat "$TMP_MERGED"

  rm -f "$TMP_EXISTING" "$TMP_NEW" "$TMP_MERGED"
}

delete_cluster_from_kubeconfig() {
  local EXISTING_KUBECONFIG="$1"
  local CLUSTER_NAME="$2"

  local TMP_EXISTING=$(mktemp)

  echo "$EXISTING_KUBECONFIG" > "$TMP_EXISTING"

  yq eval "del(.clusters[] | select(.name == \"$CLUSTER_NAME\"))" -i "$TMP_EXISTING"
  yq eval "del(.users[] | select(.name == \"$CLUSTER_NAME\"))" -i "$TMP_EXISTING"
  yq eval "del(.contexts[] | select(.name == \"$CLUSTER_NAME\"))" -i "$TMP_EXISTING"

  CURRENT_CONTEXT=$(yq eval '.current-context' "$TMP_EXISTING")
  if [ "$CURRENT_CONTEXT" == "$CLUSTER_NAME" ]; then
    FIRST_CONTEXT=$(yq eval '.contexts[0].name' "$TMP_EXISTING")
    if [ "$FIRST_CONTEXT" != "null" ] && [ -n "$FIRST_CONTEXT" ]; then
      yq eval ".current-context = \"$FIRST_CONTEXT\"" -i "$TMP_EXISTING"
    else
      yq eval "del(.current-context)" -i "$TMP_EXISTING"
    fi
  fi

  cat "$TMP_EXISTING"

  rm -f "$TMP_EXISTING"
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
      echo "Failed to extract kubeconfig"
      exit 1
    fi
  fi

  if [ -z "$KUBECONFIG_B64" ]; then
    echo "Kubeconfig secret exists but has no data"
    exit 1
  fi

  NEW_KUBECONFIG=$(echo "$KUBECONFIG_B64" | base64 -d)

  EXISTING_KUBECONFIG=$(sops -d "$SOPS_FILE" | yq '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG')

  MERGED_KUBECONFIG=$(merge_kubeconfig "$EXISTING_KUBECONFIG" "$NEW_KUBECONFIG" "$CLUSTER_NAME")

  TMP_FILE=$(mktemp)
  sops -d "$SOPS_FILE" > "$TMP_FILE"

  TMP_MERGED=$(mktemp)
  echo "$MERGED_KUBECONFIG" > "$TMP_MERGED"
  MERGED_KUBECONFIG_STR=$(cat "$TMP_MERGED")

  yq eval ".vault.kv.\"cluster-secret-store\".secrets.KUBECONFIG.KUBECONFIG = \"$MERGED_KUBECONFIG_STR\"" "$TMP_FILE" > "$TMP_FILE.updated"

  sops -e "$TMP_FILE.updated" > "$SOPS_FILE"

  rm -f "$TMP_FILE" "$TMP_FILE.updated" "$TMP_MERGED"

  echo "Updated SOPS file with kubeconfig for cluster: $CLUSTER_NAME"

elif [ "$OPERATION" == "delete" ]; then
  EXISTING_KUBECONFIG=$(sops -d "$SOPS_FILE" | yq '.vault.kv."cluster-secret-store".secrets.KUBECONFIG.KUBECONFIG')

  UPDATED_KUBECONFIG=$(delete_cluster_from_kubeconfig "$EXISTING_KUBECONFIG" "$CLUSTER_NAME")

  TMP_FILE=$(mktemp)
  sops -d "$SOPS_FILE" > "$TMP_FILE"

  TMP_UPDATED=$(mktemp)
  echo "$UPDATED_KUBECONFIG" > "$TMP_UPDATED"
  UPDATED_KUBECONFIG_STR=$(cat "$TMP_UPDATED")

  yq eval ".vault.kv.\"cluster-secret-store\".secrets.KUBECONFIG.KUBECONFIG = \"$UPDATED_KUBECONFIG_STR\"" "$TMP_FILE" > "$TMP_FILE.updated"

  sops -e "$TMP_FILE.updated" > "$SOPS_FILE"

  rm -f "$TMP_FILE" "$TMP_FILE.updated" "$TMP_UPDATED"

  echo "Removed kubeconfig for cluster: $CLUSTER_NAME from SOPS file"

else
  echo "Invalid operation: $OPERATION"
  exit 1
fi
