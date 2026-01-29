apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  namespace: default
  labels:
    ephemeral: "true"
    cluster: "${CLUSTER_NAME}"
spec:
  instances: 1

  postgresql:
    parameters:
      max_connections: "100"
      shared_buffers: "256MB"

  storage:
    size: 5Gi
    storageClass: local-path

  bootstrap:
    initdb:
      database: app
      owner: app
      secret:
        name: postgres-app-user

  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-app-user
  namespace: default
  labels:
    ephemeral: "true"
    cluster: "${CLUSTER_NAME}"
type: kubernetes.io/basic-auth
stringData:
  username: app
  password: ephemeral-password-${PR_NUMBER}
