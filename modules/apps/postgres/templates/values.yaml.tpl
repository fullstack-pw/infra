## PostgreSQL values for Helm chart
image:
  registry: ${registry}
  repository: ${repository}
  tag: "${pg_version}"
##diagnosticMode:
##  enabled: true

global:
  postgresql:
    auth:
      postgresPassword: "${postgres_password}"
      username: "${postgres_username}"
      password: "${postgres_password}"
      database: "${postgres_database}"
      existingSecret: ""

postgresql:
  extraEnvVars:
    - name: POSTGRESQL_EXTRA_FLAGS
      value: "-c shared_preload_libraries=vectors.so -c listen_addresses=* -c max_connections=200"

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
    - name: POSTGRESQL_WAL_LEVEL
      value: logical
%{if enable_ssl}
    - name: POSTGRESQL_ENABLE_TLS
      value: "yes"
    - name: POSTGRESQL_TLS_CERT_FILE
      value: "/opt/bitnami/postgresql/certs/server.crt"
    - name: POSTGRESQL_TLS_KEY_FILE
      value: "/opt/bitnami/postgresql/certs/server.key"
    - name: POSTGRESQL_TLS_CA_FILE
      value: "/opt/bitnami/postgresql/certs/ca.crt"
  extraVolumes:
    - name: teleport-certs
      secret:
        secretName: cluster-secrets
        items:
          - key: ${ssl_ca_cert_key}
            path: ca.crt
            mode: 0600
          - key: ${ssl_server_cert_key}
            path: server.crt
            mode: 0600
          - key: ${ssl_server_key_key}
            path: server.key
            mode: 0600

  extraVolumeMounts:
    - name: teleport-certs
      mountPath: /opt/bitnami/postgresql/certs
      readOnly: true
  pgHbaConfiguration: |-
    local   all             all                                     peer
    host    all             all             127.0.0.1/32            scram-sha-256
    host    all             all             ::1/128                 scram-sha-256
    hostssl all             all             10.0.0.0/8              cert clientcert=verify-full
    hostssl all             all             172.16.0.0/12           cert clientcert=verify-full
    hostssl all             all             192.168.0.0/16          cert clientcert=verify-full
    hostssl all             all             0.0.0.0/0               cert clientcert=verify-full
    hostssl all             all             ::/0                    cert clientcert=verify-full
%{endif}
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
