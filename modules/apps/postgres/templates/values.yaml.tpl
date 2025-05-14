## PostgreSQL values for Helm chart
image:
  registry: ${registry}
  repository: ${repository}
  tag: "${pg_version}"

global:
  postgresql:
    auth:
      postgresPassword: "${postgres_password}"
      username: "${postgres_username}"
      password: "${postgres_password}"
      database: "${postgres_database}"
      existingSecret: ""

# Configure PostgreSQL to accept external connections
postgresql:
  extraEnvVars:
    - name: POSTGRESQL_EXTRA_FLAGS
      value: "-c listen_addresses=* -c max_connections=200"

# Allow connections from all addresses
primary:
  service:
    type: ${service_type}
    port: ${service_port}
  extraEnvVars:
    - name: ALLOW_EMPTY_PASSWORD
      value: "no"
    - name: POSTGRESQL_CLIENT_MIN_MESSAGES
      value: "error"
    - name: POSTGRESQL_SKIP_INITDB
      value: "false"
  
  persistence:
    enabled: ${persistence_enabled}
%{if persistence_enabled && storage_class != ""}
    storageClass: "${storage_class}"
%{endif}
    size: "${persistence_size}"
  
  resources:
    requests:
      memory: "${memory_request}"
      cpu: "${cpu_request}"
    limits:
      memory: "${memory_limit}"
      cpu: "${cpu_limit}"

%{if replication_enabled}
architecture: replication

replication:
  enabled: ${replication_enabled}
  replicas: ${replication_replicas}
  synchronousCommit: ${replication_synchronousCommit}
  numSynchronousReplicas: ${replication_numSynchronousReplicas}
%{else}
architecture: standalone
%{endif}

metrics:
  enabled: ${enable_metrics}
  serviceMonitor:
    enabled: ${enable_metrics}