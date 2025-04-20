variable "namespace" {
  description = "Kubernetes namespace for PostgreSQL"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "postgres"
}

variable "chart_version" {
  description = "PostgreSQL Helm chart version"
  type        = string
  default     = "16.6.3"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "postgres_version" {
  description = "PostgreSQL version to deploy"
  type        = string
  default     = "latest"
}

# Credentials
variable "generate_credentials" {
  description = "Generate random credentials"
  type        = bool
  default     = true
}

variable "postgres_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "admin"
}

variable "postgres_password" {
  description = "PostgreSQL admin password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database to create"
  type        = string
  default     = "postgres"
}

variable "create_credentials_secret" {
  description = "Create a Kubernetes secret with the PostgreSQL credentials"
  type        = bool
  default     = true
}

# Persistence
variable "persistence_enabled" {
  description = "Enable persistence for PostgreSQL"
  type        = bool
  default     = true
}

variable "persistence_storage_class" {
  description = "Storage class for PostgreSQL PVC"
  type        = string
  default     = "local-path"
}

variable "persistence_size" {
  description = "Size of the PostgreSQL PVC"
  type        = string
  default     = "10Gi"
}

# Resources
variable "memory_request" {
  description = "Memory request for PostgreSQL pods"
  type        = string
  default     = "256Mi"
}

variable "cpu_request" {
  description = "CPU request for PostgreSQL pods"
  type        = string
  default     = "250m"
}

variable "memory_limit" {
  description = "Memory limit for PostgreSQL pods"
  type        = string
  default     = "2048Mi"
}

variable "cpu_limit" {
  description = "CPU limit for PostgreSQL pods"
  type        = string
  default     = "5000m"
}

# Metrics
variable "enable_metrics" {
  description = "Enable Prometheus metrics exporter"
  type        = bool
  default     = false
}

# Service
variable "service_type" {
  description = "Kubernetes service type"
  type        = string
  default     = "LoadBalancer"
}

variable "service_port" {
  description = "PostgreSQL service port"
  type        = number
  default     = 5432
}

# Ingress
variable "ingress_enabled" {
  description = "Enable ingress for PostgreSQL"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_host" {
  description = "Hostname for PostgreSQL ingress"
  type        = string
  default     = "postgres.fullstack.pw"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for PostgreSQL ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for PostgreSQL ingress"
  type        = string
  default     = "postgres-tls"
}

variable "ingress_annotations" {
  description = "Additional annotations for the PostgreSQL ingress"
  type        = map(string)
  default     = {}
}

variable "cert_manager_cluster_issuer" {
  description = "Name of the cert-manager ClusterIssuer to use for TLS"
  type        = string
  default     = "letsencrypt-prod"
}

# High Availability
variable "replication_enabled" {
  description = "Enable PostgreSQL replication"
  type        = bool
  default     = false
}

variable "replication_replicas" {
  description = "Number of PostgreSQL replicas"
  type        = number
  default     = 1
}

variable "high_availability_enabled" {
  description = "Enable high availability for PostgreSQL"
  type        = bool
  default     = false
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "store_password_in_vault" {
  description = "Store PostgreSQL password in Vault at the specified path"
  type        = bool
  default     = true
}

variable "vault_mount_path" {
  description = "Mount path for Vault KV store"
  type        = string
  default     = "kv"
}

variable "vault_secret_path" {
  description = "Path within the Vault KV store where the secret will be stored"
  type        = string
  default     = "cluster-secret-store/secrets/POSTGRES"
}

variable "preserve_existing_vault_data" {
  description = "Preserve existing data in the Vault secret when adding the PostgreSQL password"
  type        = bool
  default     = true
}

variable "registry" {
  default = "harbor.fullstack.pw"
}
variable "repository" {
  default = "library/postgres"
}
