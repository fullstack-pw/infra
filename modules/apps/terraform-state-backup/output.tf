/**
 * Terraform State Backup Module Outputs
 */

output "cronjob_name" {
  description = "Name of the backup CronJob"
  value       = var.name
}

output "namespace" {
  description = "Namespace where the CronJob is deployed"
  value       = var.namespace
}

output "schedule" {
  description = "Cron schedule for the backup job"
  value       = var.schedule
}

output "minio_source" {
  description = "MinIO source path being backed up"
  value       = "${var.minio_endpoint}/${var.minio_bucket_path}"
}

output "oracle_destination" {
  description = "Oracle Cloud destination path"
  value       = "oci://${var.oracle_namespace}/${var.oracle_bucket}/${var.backup_path}"
}
