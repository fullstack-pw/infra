/**
 * Oracle Backup Module
 *
 * This module deploys Kubernetes CronJobs that back up data to Oracle Cloud Object Storage.
 * Supports:
 * - S3/MinIO bucket backups
 * - PostgreSQL database backups
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

# S3/MinIO Backup CronJob (conditional)
resource "kubectl_manifest" "s3_backup_cronjob" {
  count = var.enable_s3_backup ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/s3-backup-cronjob.yaml.tpl", {
    name                          = var.s3_backup_name
    namespace                     = var.namespace
    schedule                      = var.s3_schedule
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
    backup_path                   = var.s3_backup_path
    memory_request                = var.memory_request
    memory_limit                  = var.memory_limit
    cpu_request                   = var.cpu_request
    cpu_limit                     = var.cpu_limit
  })

  wait              = true
  server_side_apply = true

  depends_on = [module.namespace]
}

# PostgreSQL Backup CronJobs (one per cluster)
resource "kubectl_manifest" "postgres_backup_cronjob" {
  for_each = var.enable_postgres_backup ? var.postgres_backups : {}

  yaml_body = templatefile("${path.module}/templates/postgres-backup-cronjob.yaml.tpl", {
    name                          = "postgres-backup-${each.key}"
    namespace                     = var.namespace
    schedule                      = each.value.schedule
    successful_jobs_history_limit = var.successful_jobs_history_limit
    failed_jobs_history_limit     = var.failed_jobs_history_limit
    backoff_limit                 = var.backoff_limit
    pg_host                       = each.value.host
    pg_port                       = each.value.port
    pg_database                   = each.value.database
    pg_username                   = each.value.username
    pg_password                   = each.value.password
    pg_ssl_enabled                = each.value.ssl_enabled
    pg_ssl_ca_cert                = each.value.ssl_ca_cert
    pg_databases                  = each.value.databases
    oracle_user_ocid              = var.oracle_user_ocid
    oracle_tenancy_ocid           = var.oracle_tenancy_ocid
    oracle_fingerprint            = var.oracle_fingerprint
    oracle_private_key            = var.oracle_private_key
    oracle_region                 = var.oracle_region
    oracle_namespace              = var.oracle_namespace
    oracle_bucket                 = var.oracle_bucket
    backup_path                   = each.value.backup_path
    cluster_name                  = each.key
    memory_request                = each.value.memory_request
    memory_limit                  = each.value.memory_limit
    cpu_request                   = each.value.cpu_request
    cpu_limit                     = each.value.cpu_limit
  })

  wait              = true
  server_side_apply = true

  depends_on = [module.namespace]
}
