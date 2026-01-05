/**
 * Oracle Backup Module Outputs
 */

# S3 Backup Outputs
output "s3_backup_cronjob_name" {
  description = "Name of the S3 backup CronJob"
  value       = var.enable_s3_backup ? var.s3_backup_name : null
}

output "s3_backup_schedule" {
  description = "Cron schedule for S3 backup job"
  value       = var.enable_s3_backup ? var.s3_schedule : null
}

output "s3_backup_source" {
  description = "MinIO source path being backed up"
  value       = var.enable_s3_backup ? "${var.minio_endpoint}/${var.minio_bucket_path}" : null
}

output "s3_backup_destination" {
  description = "Oracle Cloud destination path for S3 backup"
  value       = var.enable_s3_backup ? "oci://${var.oracle_namespace}/${var.oracle_bucket}/${var.s3_backup_path}" : null
}

# PostgreSQL Backup Outputs
output "postgres_backup_cronjobs" {
  description = "Map of PostgreSQL backup CronJob details"
  sensitive   = true
  value = var.enable_postgres_backup ? {
    for key, config in var.postgres_backups : key => {
      cronjob_name = "postgres-backup-${key}"
      schedule     = config.schedule
      source       = "${config.host}:${config.port}/${config.database}"
      destination  = "oci://${var.oracle_namespace}/${var.oracle_bucket}/${config.backup_path}"
    }
  } : {}
}

# Common Outputs
output "namespace" {
  description = "Namespace where CronJobs are deployed"
  value       = var.namespace
}

output "oracle_bucket" {
  description = "Oracle Cloud Object Storage bucket"
  value       = var.oracle_bucket
}
