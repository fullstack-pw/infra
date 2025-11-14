/**
 * Terraform State Backup Module Variables
 *
 * This module creates a CronJob to backup Terraform state files from MinIO to Oracle Cloud Object Storage.
 */

variable "name" {
  description = "Name of the backup CronJob"
  type        = string
  default     = "terraform-state-backup"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the CronJob"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Whether to create the namespace"
  type        = bool
  default     = false
}

# Schedule Configuration
variable "schedule" {
  description = "Cron schedule for the backup job (default: daily at 2 AM UTC)"
  type        = string
  default     = "0 2 * * *"
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

# MinIO Configuration
variable "minio_endpoint" {
  description = "MinIO S3 endpoint (e.g., https://s3.fullstack.pw)"
  type        = string
}

variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
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

variable "backup_path" {
  description = "Path within Oracle Cloud bucket to store backups"
  type        = string
  default     = "backup"
}

# MinIO Client Configuration
# Note: Using minio/mc:latest image, no additional configuration needed

# Resource Configuration
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
