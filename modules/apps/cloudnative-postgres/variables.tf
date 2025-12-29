variable "cluster_name" {
  description = "Name of the PostgreSQL cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "create_cluster" {
  description = "Create the PostgreSQL cluster (set to false on first apply, then true after operator CRDs are installed)"
  type        = bool
  default     = false
}

variable "instances" {
  description = "Number of PostgreSQL instances"
  type        = number
  default     = 1
}

variable "registry" {
  description = "Container registry"
  type        = string
  default     = "docker.io"
}

variable "repository" {
  description = "Container repository"
  type        = string
}

variable "pg_version" {
  description = "PostgreSQL version tag"
  type        = string
}

variable "postgres_database" {
  description = "Default database name"
  type        = string
  default     = "postgres"
}

variable "postgres_username" {
  description = "Superuser username"
  type        = string
  default     = "admin"
}

variable "postgres_password" {
  description = "Superuser password (only used if postgres_generate_password is false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_generate_password" {
  description = "Generate random password for postgres superuser"
  type        = bool
  default     = true
}

variable "persistence_size" {
  description = "PVC size"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for PVC"
  type        = string
  default     = ""
}

variable "memory_request" {
  description = "Memory request"
  type        = string
  default     = "256Mi"
}

variable "memory_limit" {
  description = "Memory limit"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request"
  type        = string
  default     = "100m"
}

variable "cpu_limit" {
  description = "CPU limit"
  type        = string
  default     = "500m"
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for pg_hba.conf rules (hostssl). CNPG always generates its own server certificates."
  type        = bool
  default     = false
}

variable "use_custom_server_certs" {
  description = "Use custom server certificates instead of CNPG-managed ones. Only set to true if you have valid CA/cert/key that form a proper chain."
  type        = bool
  default     = false
}

variable "ssl_ca_cert_key" {
  description = "Vault secret key for CA certificate"
  type        = string
  default     = "SSL_CA"
}

variable "ssl_server_cert_key" {
  description = "Vault secret key for server certificate"
  type        = string
  default     = "SSL_CERT"
}

variable "ssl_server_key_key" {
  description = "Vault secret key for server private key"
  type        = string
  default     = "SSL_KEY"
}

variable "ssl_ca_cert" {
  description = "SSL CA certificate content (if not provided, will try to read from cluster-secrets)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssl_server_cert" {
  description = "SSL server certificate content (if not provided, will try to read from cluster-secrets)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssl_server_key" {
  description = "SSL server private key content (if not provided, will try to read from cluster-secrets)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_app_user" {
  description = "Create an application user"
  type        = bool
  default     = false
}

variable "app_username" {
  description = "Application username"
  type        = string
  default     = "appuser"
}

variable "app_user_generate_password" {
  description = "Generate random password for app user"
  type        = bool
  default     = true
}

variable "needs_secrets" {
  description = "Whether to store secrets in Vault"
  type        = bool
  default     = true
}

variable "vault_secret_path" {
  description = "Vault path for storing credentials"
  type        = string
  default     = "cluster-secret-store/secrets/POSTGRES"
}

variable "export_credentials_to_namespace" {
  description = "Export credentials secret to another namespace for app access"
  type        = string
  default     = ""
}

variable "export_credentials_secret_name" {
  description = "Name of the exported credentials secret"
  type        = string
  default     = "postgres-credentials"
}

variable "additional_client_ca_certs" {
  description = "Additional CA certificates to trust for client authentication (e.g., Teleport DB CA). List of PEM-encoded certificates."
  type        = list(string)
  default     = []
}
