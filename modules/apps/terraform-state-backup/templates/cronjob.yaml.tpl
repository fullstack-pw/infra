apiVersion: batch/v1
kind: CronJob
metadata:
  name: ${name}
  namespace: ${namespace}
  labels:
    app: ${name}
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
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup-sync
            image: alpine:latest
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - |
              set -e
              echo "================================================"
              echo "Terraform State Backup - $(date)"
              echo "================================================"
              echo "Source: MinIO s3://${minio_bucket_path}"
              echo "Destination: Oracle Cloud bucket://${oracle_bucket}/${backup_path}"
              echo ""

              # Install required tools
              echo "Installing MinIO Client..."
              wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
              chmod +x /usr/local/bin/mc

              echo "Installing Oracle Cloud CLI..."
              apk add --no-cache python3 py3-pip bash
              mkdir venv
              python3 -m venv ./venv
              source ./venv/bin/activate
              pip3 install --no-cache-dir oci-cli

              echo ""
              echo "================================================"
              echo "Step 1: Download from MinIO"
              echo "================================================"

              # Configure MinIO alias
              echo "Configuring MinIO connection..."
              mc alias set minio ${minio_endpoint} ${minio_access_key} ${minio_secret_key}

              # Test MinIO connection
              echo "Testing MinIO connection..."
              mc ls minio/${minio_bucket_path}

              # Download files from MinIO to local temp directory
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

              # Configure OCI CLI
              echo "Configuring Oracle Cloud CLI..."
              mkdir -p ~/.oci

              echo "[DEFAULT]" > ~/.oci/config
              echo "user=${oracle_user_ocid}" >> ~/.oci/config
              echo "fingerprint=${oracle_fingerprint}" >> ~/.oci/config
              echo "tenancy=${oracle_tenancy_ocid}" >> ~/.oci/config
              echo "region=${oracle_region}" >> ~/.oci/config
              echo "key_file=~/.oci/key.pem" >> ~/.oci/config

              # Write private key from environment variable
              echo "$ORACLE_PRIVATE_KEY" > ~/.oci/key.pem
              chmod 600 ~/.oci/key.pem

              # Test OCI connection
              echo "Testing Oracle Cloud connection..."
              oci os bucket get --bucket-name ${oracle_bucket} --namespace ${oracle_namespace}

              # Upload files to Oracle Cloud
              echo ""
              echo "Uploading files to Oracle Cloud..."
              oci os object bulk-upload \
                --namespace ${oracle_namespace} \
                --bucket-name ${oracle_bucket} \
                --src-dir /tmp/backup \
                --prefix ${backup_path}/ \
                --overwrite

              echo ""
              echo "================================================"
              echo "Backup completed successfully - $(date)"
              echo "================================================"

              # List uploaded files
              echo ""
              echo "Files in Oracle Cloud:"
              oci os object list \
                --namespace ${oracle_namespace} \
                --bucket-name ${oracle_bucket} \
                --prefix ${backup_path}/ \
                --fields name,size,timeCreated

              # Cleanup
              echo ""
              echo "Cleaning up temporary files..."
              rm -rf /tmp/backup ~/.oci
            env:
            - name: MINIO_ENDPOINT
              value: "${minio_endpoint}"
            - name: MINIO_ACCESS_KEY
              value: "${minio_access_key}"
            - name: MINIO_SECRET_KEY
              value: "${minio_secret_key}"
            - name: MINIO_REGION
              value: "${minio_region}"
            - name: ORACLE_USER_OCID
              value: "${oracle_user_ocid}"
            - name: ORACLE_TENANCY_OCID
              value: "${oracle_tenancy_ocid}"
            - name: ORACLE_FINGERPRINT
              value: "${oracle_fingerprint}"
            - name: ORACLE_REGION
              value: "${oracle_region}"
            - name: ORACLE_NAMESPACE
              value: "${oracle_namespace}"
            - name: ORACLE_BUCKET
              value: "${oracle_bucket}"
            - name: ORACLE_PRIVATE_KEY
              value: "${oracle_private_key}"
            resources:
              requests:
                memory: "${memory_request}"
                cpu: "${cpu_request}"
              limits:
                memory: "${memory_limit}"
                cpu: "${cpu_limit}"
