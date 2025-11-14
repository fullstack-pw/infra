/**
 * Terraform State Backup Module
 *
 * This module deploys a Kubernetes CronJob that backs up Terraform state files
 * from MinIO S3 to Oracle Cloud Object Storage.
 */

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

# Create namespace if requested
module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

# Note: ConfigMap is not needed anymore - credentials are passed directly to the CronJob
# The configmap.yaml.tpl template is kept for historical reference only

# Deploy the CronJob
resource "kubectl_manifest" "backup_cronjob" {
  yaml_body = templatefile("${path.module}/templates/cronjob.yaml.tpl", {
    name                          = var.name
    namespace                     = var.namespace
    schedule                      = var.schedule
    successful_jobs_history_limit = var.successful_jobs_history_limit
    failed_jobs_history_limit     = var.failed_jobs_history_limit
    backoff_limit                 = var.backoff_limit
    minio_endpoint                = var.minio_endpoint
    minio_access_key              = var.minio_access_key
    minio_secret_key              = var.minio_secret_key
    minio_region                  = var.minio_region
    minio_bucket_path             = var.minio_bucket_path
    oracle_user_ocid              = var.oracle_user_ocid
    oracle_tenancy_ocid           = var.oracle_tenancy_ocid
    oracle_fingerprint            = var.oracle_fingerprint
    oracle_private_key            = var.oracle_private_key
    oracle_region                 = var.oracle_region
    oracle_namespace              = var.oracle_namespace
    oracle_bucket                 = var.oracle_bucket
    backup_path                   = var.backup_path
    memory_request                = var.memory_request
    memory_limit                  = var.memory_limit
    cpu_request                   = var.cpu_request
    cpu_limit                     = var.cpu_limit
  })

  wait              = true
  server_side_apply = true

  depends_on = [module.namespace]
}
