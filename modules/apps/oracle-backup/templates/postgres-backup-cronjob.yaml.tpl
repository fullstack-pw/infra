apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
    backup-type: postgres
    cluster: ${cluster_name}
spec:
  schedule: "${schedule}"
  successfulJobsHistoryLimit: ${successful_jobs_history_limit}
  failedJobsHistoryLimit: ${failed_jobs_history_limit}
  jobTemplate:
    spec:
      backoffLimit: ${backoff_limit}
      template:
        metadata:
          labels:
            app: ${name}
            backup-type: postgres
        spec:
          restartPolicy: OnFailure
          containers:
          - name: postgres-backup
            image: alpine:3.20
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - |
              set -e
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              echo "================================================"
              echo "PostgreSQL Backup - $(date)"
              echo "================================================"
              echo "Cluster: ${cluster_name}"
              echo "Host: ${pg_host}:${pg_port}"
              echo "Database: ${pg_database}"
              echo "Destination: Oracle Cloud bucket://$ORACLE_BUCKET/${backup_path}"
              echo ""

              echo "Installing PostgreSQL client and OCI CLI..."
              apk add --no-cache postgresql16-client python3 py3-pip bash

              mkdir -p /tmp/venv
              python3 -m venv /tmp/venv
              source /tmp/venv/bin/activate
              pip3 install --no-cache-dir oci-cli

%{ if pg_ssl_enabled }
              echo "Setting up SSL certificates..."
              mkdir -p /tmp/ssl
              echo "$PG_SSL_CA" > /tmp/ssl/ca.crt
              chmod 600 /tmp/ssl/ca.crt
              export PGSSLMODE=verify-ca
              export PGSSLROOTCERT=/tmp/ssl/ca.crt
%{ else }
              export PGSSLMODE=disable
%{ endif }

              echo ""
              echo "================================================"
              echo "Step 1: Dump PostgreSQL Database"
              echo "================================================"

              mkdir -p /tmp/backup

              echo "Testing PostgreSQL connection..."
              PGPASSWORD="$PG_PASSWORD" psql -h ${pg_host} -p ${pg_port} -U ${pg_username} -d ${pg_database} -c "SELECT version();"

%{ if length(pg_databases) > 0 }
%{ for db in pg_databases }
              echo "Dumping database: ${db}"
              PGPASSWORD="$PG_PASSWORD" pg_dump \
                -h ${pg_host} \
                -p ${pg_port} \
                -U ${pg_username} \
                -d ${db} \
                --format=custom \
                --compress=9 \
                --file=/tmp/backup/${cluster_name}_${db}_$TIMESTAMP.dump
%{ endfor }
%{ else }
              echo "Discovering all databases..."
              DATABASES=$(PGPASSWORD="$PG_PASSWORD" psql -h ${pg_host} -p ${pg_port} -U ${pg_username} -d ${pg_database} -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres') ORDER BY datname;")
              DATABASES="postgres $DATABASES"

              echo "Found databases: $DATABASES"
              for db in $DATABASES; do
                echo "Dumping database: $db"
                PGPASSWORD="$PG_PASSWORD" pg_dump \
                  -h ${pg_host} \
                  -p ${pg_port} \
                  -U ${pg_username} \
                  -d "$db" \
                  --format=custom \
                  --compress=9 \
                  --file=/tmp/backup/${cluster_name}_"$db"_$TIMESTAMP.dump
              done
%{ endif }

              echo ""
              echo "Backup files created:"
              ls -lah /tmp/backup/

              echo ""
              echo "================================================"
              echo "Step 2: Upload to Oracle Cloud"
              echo "================================================"

              echo "Configuring Oracle Cloud CLI..."
              mkdir -p ~/.oci

              cat > ~/.oci/config << OCICONFIG
              [DEFAULT]
              user=$ORACLE_USER_OCID
              fingerprint=$ORACLE_FINGERPRINT
              tenancy=$ORACLE_TENANCY_OCID
              region=$ORACLE_REGION
              key_file=~/.oci/key.pem
              OCICONFIG

              echo "$ORACLE_PRIVATE_KEY" > ~/.oci/key.pem
              chmod 600 ~/.oci/key.pem ~/.oci/config

              echo "Testing Oracle Cloud connection..."
              oci os bucket get --bucket-name "$ORACLE_BUCKET" --namespace "$ORACLE_NAMESPACE"

              echo ""
              echo "Uploading backup files to Oracle Cloud..."
              oci os object bulk-upload \
                --namespace "$ORACLE_NAMESPACE" \
                --bucket-name "$ORACLE_BUCKET" \
                --src-dir /tmp/backup \
                --prefix ${backup_path}/ \
                --overwrite

              echo ""
              echo "================================================"
              echo "Backup completed successfully - $(date)"
              echo "================================================"

              echo ""
              echo "Files in Oracle Cloud:"
              oci os object list \
                --namespace "$ORACLE_NAMESPACE" \
                --bucket-name "$ORACLE_BUCKET" \
                --prefix ${backup_path}/ \
                --fields name,size,timeCreated

              echo ""
              echo "Cleaning up temporary files..."
              rm -rf /tmp/backup /tmp/ssl /tmp/venv ~/.oci
            env:
            - name: PG_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: ${postgres_password_key}
%{ if pg_ssl_enabled }
            - name: PG_SSL_CA
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: ssl_ca_cert
%{ endif }
            - name: ORACLE_USER_OCID
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: userOcid
            - name: ORACLE_TENANCY_OCID
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: tenancyOcid
            - name: ORACLE_FINGERPRINT
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: fingerprint
            - name: ORACLE_REGION
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: region
            - name: ORACLE_NAMESPACE
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: namespace
            - name: ORACLE_BUCKET
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: bucket
            - name: ORACLE_PRIVATE_KEY
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: privateKey
            resources:
              requests:
                memory: "${memory_request}"
                cpu: "${cpu_request}"
              limits:
                memory: "${memory_limit}"
                cpu: "${cpu_limit}"
