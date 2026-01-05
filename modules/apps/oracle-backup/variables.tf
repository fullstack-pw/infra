/**
 * Oracle Backup Module Variables
 *
 * This module creates CronJobs to backup data to Oracle Cloud Object Storage.
 * Supports S3/MinIO backups and PostgreSQL database backups.
 */

variable "namespace" {
  description = "Kubernetes namespace to deploy the CronJobs"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Whether to create the namespace"
  type        = bool
  default     = false
}

# Backup Type Enablement
variable "enable_s3_backup" {
  description = "Enable S3/MinIO backup CronJob"
  type        = bool
  default     = true
}

variable "enable_postgres_backup" {
  description = "Enable PostgreSQL backup CronJob"
  type        = bool
  default     = false
}

# S3 Backup Configuration
variable "s3_backup_name" {
  description = "Name of the S3 backup CronJob"
  type        = string
  default     = "s3-backup"
}

variable "s3_schedule" {
  description = "Cron schedule for S3 backup job (default: daily at 2 AM UTC)"
  type        = string
  default     = "0 2 * * *"
}

variable "s3_backup_path" {
  description = "Path within Oracle Cloud bucket for S3 backups"
  type        = string
  default     = "s3-backup"
}

variable "successful_jobs_history_limit" {
  description = "Number of successful jobs to keep"
  type        = number
  default     = 3
}

variable "failed_jobs_history_limit" {
  description = "Number of failed jobs to keep"
  type        = number
  default     = 3
}

variable "backoff_limit" {
  description = "Number of retries before marking job as failed"
  type        = number
  default     = 3
}

# MinIO Configuration (required when enable_s3_backup = true)
variable "minio_endpoint" {
  description = "MinIO S3 endpoint (e.g., https://s3.fullstack.pw)"
  type        = string
  default     = ""
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "minio_region" {
  description = "MinIO region"
  type        = string
  default     = "main"
}

variable "minio_bucket_path" {
  description = "MinIO bucket and path to backup (e.g., terraform/infrastructure.tfstate or terraform/ for entire bucket)"
  type        = string
  default     = "terraform"
}

# Oracle Cloud Configuration (OCI CLI Authentication)
variable "oracle_user_ocid" {
  description = "Oracle Cloud user OCID for API authentication"
  type        = string
  sensitive   = true
}

variable "oracle_tenancy_ocid" {
  description = "Oracle Cloud tenancy OCID"
  type        = string
  sensitive   = true
}

variable "oracle_fingerprint" {
  description = "Fingerprint of the API signing key"
  type        = string
  sensitive   = true
}

variable "oracle_private_key" {
  description = "Private API signing key in PEM format"
  type        = string
  sensitive   = true
}

variable "oracle_region" {
  description = "Oracle Cloud region (e.g., eu-madrid-1)"
  type        = string
}

variable "oracle_namespace" {
  description = "Oracle Cloud Object Storage namespace"
  type        = string
}

variable "oracle_bucket" {
  description = "Oracle Cloud Object Storage bucket name"
  type        = string
}

# PostgreSQL Backup Configuration
variable "postgres_backups" {
  description = "Map of PostgreSQL clusters to backup"
  type = map(object({
    host           = string
    port           = number
    database       = string
    username       = string
    password       = string
    ssl_enabled    = bool
    ssl_ca_cert    = optional(string, "")
    schedule       = string
    backup_path    = string
    databases      = optional(list(string), [])
    memory_request = optional(string, "256Mi")
    memory_limit   = optional(string, "1Gi")
    cpu_request    = optional(string, "200m")
    cpu_limit      = optional(string, "1000m")
  }))
  default = {}
}

# S3 Backup Resource Configuration
variable "memory_request" {
  description = "Memory request for the backup job"
  type        = string
  default     = "128Mi"
}

variable "memory_limit" {
  description = "Memory limit for the backup job"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request for the backup job"
  type        = string
  default     = "100m"
}

variable "cpu_limit" {
  description = "CPU limit for the backup job"
  type        = string
  default     = "500m"
}
