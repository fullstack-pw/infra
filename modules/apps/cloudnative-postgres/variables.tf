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

variable "require_cert_auth_for_admin" {
  description = "Require client certificate authentication for admin user. Set to false to allow password auth from external networks."
  type        = bool
  default     = true
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

variable "additional_databases" {
  description = "Additional databases to create"
  type        = list(string)
  default     = []
}

variable "additional_users" {
  description = "Additional database users to create with password auth and REPLICATION privilege"
  type = list(object({
    username  = string
    password  = string
    databases = list(string)
  }))
  default = []
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

variable "ingress_enabled" {
  description = "Enable ingress for external access"
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname for ingress (e.g., tools.postgres.fullstack.pw)"
  type        = string
  default     = ""
}

variable "ingress_class_name" {
  description = "Ingress class name (e.g., traefik, nginx)"
  type        = string
  default     = "traefik"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for ingress"
  type        = string
  default     = ""
}

variable "cert_manager_cluster_issuer" {
  description = "cert-manager cluster issuer name"
  type        = string
  default     = "letsencrypt-prod"
}

variable "ingress_annotations" {
  description = "Additional annotations for ingress"
  type        = map(string)
  default     = {}
}

variable "use_istio" {
  description = "Use Istio Gateway/VirtualService instead of standard Ingress"
  type        = bool
  default     = false
}

variable "istio_CRDs" {
  description = "Whether Istio CRDs are available (set to true after Istio is installed)"
  type        = bool
  default     = false
}

variable "istio_gateway_namespace" {
  description = "Namespace where Istio ingress gateway is deployed"
  type        = string
  default     = "istio-system"
}

variable "service_port" {
  description = "PostgreSQL service port"
  type        = number
  default     = 5432
}

variable "create_backup_user" {
  description = "Create a dedicated backup user with read-only access for pg_dump"
  type        = bool
  default     = false
}

variable "backup_username" {
  description = "Backup user username"
  type        = string
  default     = "backup"
}

variable "backup_password" {
  description = "Backup user password (if empty and create_backup_user=true, will be generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "backup_generate_password" {
  description = "Generate random password for backup user"
  type        = bool
  default     = true
}

variable "enable_superuser_access" {
  description = "Enable superuser access via CNPG. Creates a <cluster>-superuser secret with postgres credentials."
  type        = bool
  default     = true
}

variable "cert_auth_users" {
  description = "List of usernames that require SSL certificate authentication"
  type        = list(string)
  default     = []
}

variable "managed_roles" {
  description = "List of roles to be managed declaratively by CNPG operator"
  type = list(object({
    name                 = string
    ensure               = optional(string, "present")
    login                = optional(bool, true)
    superuser            = optional(bool, false)
    createdb             = optional(bool, false)
    createrole           = optional(bool, false)
    inherit              = optional(bool, true)
    replication          = optional(bool, false)
    bypassrls            = optional(bool, false)
    connection_limit     = optional(number, -1)
    valid_until          = optional(string)
    in_roles             = optional(list(string), [])
    password_secret_name = optional(string)
    disable_password     = optional(bool, false)
  }))
  default = []
}

variable "export_ca_to_vault" {
  description = "Export the PostgreSQL CA certificate to Vault (useful for Teleport integration)"
  type        = bool
  default     = false
}

variable "vault_ca_secret_path" {
  description = "Vault path for storing the CA certificate (when export_ca_to_vault is true)"
  type        = string
  default     = ""
}

variable "vault_ca_secret_key" {
  description = "Vault secret key name for the CA certificate"
  type        = string
  default     = "CA"
}
