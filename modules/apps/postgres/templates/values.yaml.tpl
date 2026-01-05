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

primary:
  service:
    type: ${service_type}
    port: ${service_port}
%{if create_app_user || grant_replication_to_admin}
  initdb:
    scripts:
%{if grant_replication_to_admin}
      grant-replication.sh: |
        #!/bin/bash
        set -e
        export PGPASSWORD="$POSTGRES_POSTGRES_PASSWORD"
        psql -v ON_ERROR_STOP=1 --username="postgres" --dbname="${postgres_database}" <<-EOSQL
          ALTER USER ${postgres_username} WITH REPLICATION;
        EOSQL
%{endif}
%{if create_app_user}
      create-app-user.sh: |
        #!/bin/bash
        set -e
        export PGPASSWORD="$POSTGRES_POSTGRES_PASSWORD"
        psql -v ON_ERROR_STOP=1 --username="postgres" --dbname="${postgres_database}" <<-EOSQL
          DO \$\$
          BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${app_username}') THEN
              CREATE USER ${app_username} WITH PASSWORD '${app_user_password}';
            END IF;
          END
          \$\$;
          GRANT ALL PRIVILEGES ON DATABASE ${postgres_database} TO ${app_username};
          GRANT ALL PRIVILEGES ON SCHEMA public TO ${app_username};
          GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${app_username};
          GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${app_username};
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${app_username};
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${app_username};
        EOSQL
%{endif}
%{endif}
  extraEnvVars:
    - name: ALLOW_EMPTY_PASSWORD
      value: "no"
    - name: POSTGRESQL_CLIENT_MIN_MESSAGES
      value: "error"
    - name: POSTGRESQL_WAL_LEVEL
      value: logical
%{if enable_ssl}
  initContainers:
    - name: fix-data-permissions
      image: ${registry}/${repository}:${pg_version}
      command:
        - sh
        - -c
        - |
          mkdir -p /bitnami/postgresql/data
          chown -R 999:999 /bitnami/postgresql
          chmod 700 /bitnami/postgresql/data
      volumeMounts:
        - name: data
          mountPath: /bitnami/postgresql
      securityContext:
        runAsUser: 0  # Run as root to change ownership
    - name: copy-certs
      image: ${registry}/${repository}:${pg_version}
      securityContext:
        runAsUser: 999  # Changed from 1001 to match official postgres UID
        runAsGroup: 999
      command:
        - sh
        - -c
        - |
          cp /tmp/certs/* /certs/
          chmod 600 /certs/server.key
          chmod 644 /certs/server.crt /certs/ca.crt
      volumeMounts:
        - name: teleport-certs-source
          mountPath: /tmp/certs
          readOnly: true
        - name: teleport-certs
          mountPath: /certs
  extraVolumes:
    - name: teleport-certs-source
      secret:
        secretName: cluster-secrets
        items:
          - key: ${ssl_ca_cert_key}
            path: ca.crt
          - key: ${ssl_server_cert_key}
            path: server.crt
          - key: ${ssl_server_key_key}
            path: server.key
    - name: teleport-certs
      emptyDir: {}

  extraVolumeMounts:
    - name: teleport-certs
      mountPath: /var/lib/postgresql/certs
  command:
    - postgres
    - "-c"
    - "shared_preload_libraries=vectors.so"
    - "-c"
    - "ssl=on"
    - "-c"
    - "ssl_cert_file=/var/lib/postgresql/certs/server.crt"
    - "-c"
    - "ssl_key_file=/var/lib/postgresql/certs/server.key"
    - "-c"
    - "ssl_ca_file=/var/lib/postgresql/certs/ca.crt"
  pgHbaConfiguration: |-
    local   all             all                                     scram-sha-256
    host    all             all             127.0.0.1/32            scram-sha-256
    host    all             all             ::1/128                 scram-sha-256
    hostssl all             appuser         10.42.0.0/16            scram-sha-256
    hostssl all             appuser         10.43.0.0/16            scram-sha-256
    hostssl all             admin           0.0.0.0/0               cert clientcert=verify-full
    hostssl all             admin           ::/0                    cert clientcert=verify-full
    hostssl all             all             0.0.0.0/0               scram-sha-256
    hostssl all             all             ::/0                    scram-sha-256
%{endif}
  persistence:
    enabled: ${persistence_enabled}
%{if persistence_enabled && storage_class != ""}
    storageClass: "${storage_class}"
    mountPath: "/var/lib/postgresql/data"
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
