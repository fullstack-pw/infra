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

variable "needs_secrets" {
  description = "Add cluster-secrets=true label to namespace for external-secrets sync"
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
  #default     = "16.2.0" #using pg17.0
  default = "12.12.10" #using pg15.4
}

variable "postgres_version" { #postgres docker image version
  default = "latest"
}

variable "registry" {
  default = "registry.fullstack.pw"
}
variable "repository" {
  default = "library/postgres"
}



variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 120
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

# Istio Ingress
variable "use_istio" {
  description = "Use Istio Gateway/VirtualService instead of traditional Ingress"
  type        = bool
  default     = false
}

variable "istio_gateway_name" {
  description = "Name of the Istio Gateway to use (format: namespace/gateway-name)"
  type        = string
  default     = "istio-system/default-gateway"
}

variable "istio_gateway_namespace" {
  description = "Namespace where the Istio Gateway is located"
  type        = string
  default     = "istio-system"
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

variable "replication_synchronousCommit" {
  default = "on"
}
variable "replication_numSynchronousReplicas" {
  default = 1
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

# registry.fullstack.pw/library/postgres:1.2.0
# docker.io/bitnami/postgresql:15.4.0

# variable "registry" {
#   default = "docker.io"
# }
# variable "repository" {
#   default = "bitnami/postgresql"
# }

# variable "postgres_version" {
#   default = "15.4.0"
# }

variable "enable_ssl" {
  description = "Enable database access with SSL certificates"
  type        = bool
  default     = false
}

variable "ssl_ca_cert_key" {
  description = "Vault secret key containing CA certificate"
  type        = string
  default     = "SSL_CA"
  #default = ""
}

variable "ssl_server_cert_key" {
  description = "Vault secret key containing server certificate"
  type        = string
  default     = "SSL_CERT"
  #default = ""
}

variable "ssl_server_key_key" {
  description = "Vault secret key containing server private key"
  type        = string
  default     = "SSL_KEY"
  #default = ""
}

# Application User
variable "create_app_user" {
  description = "Create an application user for password-based authentication"
  type        = bool
  default     = false
}

variable "app_username" {
  description = "Application username"
  type        = string
  default     = "appuser"
}

variable "app_user_generate_password" {
  description = "Generate random password for application user"
  type        = bool
  default     = true
}

variable "app_user_password" {
  description = "Application user password (if not generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "istio_CRDs" {
  description = "Enable after installing core istio to install resources that need CRDs"
  type        = bool
  default     = true
}
