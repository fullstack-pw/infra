variable "namespace" {
  description = "Kubernetes namespace for Authentik"
  type        = string
  default     = "authentik"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "authentik"
}

variable "chart_version" {
  description = "Authentik Helm chart version"
  type        = string
  default     = "2024.12.3"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "domain" {
  description = "Domain for Authentik"
  type        = string
  default     = "auth.fullstack.pw"
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "authentik_secret_key" {
  description = "Secret key for Authentik"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Initial admin password"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email address"
  type        = string
  default     = "admin@fullstack.pw"
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "postgres-rw.default.svc.cluster.local"
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "authentik"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_secret_name" {
  description = "Name of the Kubernetes secret containing PostgreSQL credentials (must have 'password' key)"
  type        = string
  default     = "postgres-superuser"
}

variable "postgres_secret_namespace" {
  description = "Namespace of the Kubernetes secret containing PostgreSQL credentials"
  type        = string
  default     = "default"
}

variable "redis_host" {
  description = "Redis host"
  type        = string
  default     = "redis-redis-master.default.svc.cluster.local"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "redis_db" {
  description = "Redis database index"
  type        = number
  default     = 1
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
