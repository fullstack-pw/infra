---
# ExternalSecret template (optional)
# Syncs secrets from Vault to Kubernetes
# Requires SecretStore to be configured in Phase 1

apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.fullstack.pw"
      path: "kv"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cluster-secrets
  namespace: default
  labels:
    ephemeral: "true"
    cluster: "${CLUSTER_NAME}"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: cluster-secrets
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: kv/data/ephemeral-clusters/${CLUSTER_NAME}/secrets
