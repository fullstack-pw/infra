apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
    backup-type: s3
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
            backup-type: s3
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup-sync
            image: alpine:3.20
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - |
              set -e
              echo "================================================"
              echo "S3/MinIO Backup - $(date)"
              echo "================================================"
              echo "Source: MinIO s3://${minio_bucket_path}"
              echo "Destination: Oracle Cloud bucket://$ORACLE_BUCKET/${backup_path}"
              echo ""

              echo "Installing MinIO Client..."
              wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
              chmod +x /usr/local/bin/mc

              echo "Installing Oracle Cloud CLI..."
              apk add --no-cache python3 py3-pip bash
              mkdir -p /tmp/venv
              python3 -m venv /tmp/venv
              source /tmp/venv/bin/activate
              pip3 install --no-cache-dir oci-cli

              echo ""
              echo "================================================"
              echo "Step 1: Download from MinIO"
              echo "================================================"

              echo "Configuring MinIO connection..."
              mc alias set minio "${minio_endpoint}" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"

              echo "Testing MinIO connection..."
              mc ls minio/${minio_bucket_path}

              echo ""
              echo "Downloading files from MinIO..."
              mkdir -p /tmp/backup
              mc mirror minio/${minio_bucket_path} /tmp/backup/

              echo ""
              echo "Files downloaded:"
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
              echo "Uploading files to Oracle Cloud..."
              oci os object bulk-upload \
                --namespace "$ORACLE_NAMESPACE" \
                --bucket-name "$ORACLE_BUCKET" \
                --src-dir /tmp/backup \
                --prefix ${backup_path}/ \
                --storage-tier ${oracle_storage_tier} \
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
              rm -rf /tmp/backup /tmp/venv ~/.oci
            env:
            - name: MINIO_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: rootUser
            - name: MINIO_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: cluster-secrets
                  key: rootPassword
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
