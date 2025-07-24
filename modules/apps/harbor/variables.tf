variable "namespace" {
  description = "Kubernetes namespace for Harbor"
  type        = string
  default     = "harbor"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "harbor"
}

variable "chart_version" {
  description = "Harbor Helm chart version"
  type        = string
  default     = "1.16.2"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

# Domain configuration
variable "harbor_domain" {
  description = "Domain for Harbor"
  type        = string
  default     = "registry.fullstack.pw"
}

variable "notary_domain" {
  description = "Domain for Notary service"
  type        = string
  default     = "notary.fullstack.pw"
}

# Storage
variable "persistence_enabled" {
  description = "Enable persistence for Harbor components"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class to use for persistent volumes"
  type        = string
  default     = "local-path"
}

# External database
variable "use_external_database" {
  description = "Use external PostgreSQL database"
  type        = bool
  default     = true
}

variable "external_database_host" {
  description = "External PostgreSQL host"
  type        = string
  default     = "postgres.fullstack.pw"
}

variable "external_database_port" {
  description = "External PostgreSQL port"
  type        = number
  default     = 5432
}

variable "external_database_username" {
  description = "External PostgreSQL username"
  type        = string
  default     = "admin"
}

variable "external_database_password" {
  description = "External PostgreSQL password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_database_sslmode" {
  description = "External PostgreSQL SSL mode"
  type        = string
  default     = "disable"
}

variable "external_database_database" {
  description = "External PostgreSQL database name"
  type        = string
  default     = "harbor"
}

# External Redis
variable "use_external_redis" {
  description = "Use external Redis"
  type        = bool
  default     = true
}

variable "external_redis_host" {
  description = "External Redis host"
  type        = string
  default     = "redis.fullstack.pw"
}

variable "external_redis_port" {
  description = "External Redis port"
  type        = number
  default     = 6379
}

variable "external_redis_password" {
  description = "External Redis password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_redis_database_index" {
  description = "External Redis database index"
  type        = number
  default     = 0
}

# Admin credentials
variable "admin_password" {
  description = "Harbor admin password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "generate_admin_password" {
  description = "Generate a random admin password"
  type        = bool
  default     = true
}

# Ingress configuration
variable "ingress_enabled" {
  description = "Enable ingress for Harbor"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name for Harbor"
  type        = string
  default     = "traefik"
}

variable "ingress_annotations" {
  description = "Annotations for Harbor ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname"   = "registry.fullstack.pw"
    "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
    "nginx.org/client-max-body-size"              = "0"
  }
}

variable "tls_enabled" {
  description = "Enable TLS for Harbor"
  type        = bool
  default     = true
}

variable "tls_cert_secret_name" {
  description = "Secret name for TLS certificate"
  type        = string
  default     = "harbor-tls"
}

# Resource limits
variable "resources_limits" {
  description = "Resource limits for Harbor components"
  type = map(object({
    cpu    = string
    memory = string
  }))
  default = {
    core = {
      cpu    = "1000m"
      memory = "128Mi"
    },
    jobservice = {
      cpu    = "500m"
      memory = "128Mi"
    },
    registry = {
      cpu    = "500m"
      memory = "128Mi"
    },
    portal = {
      cpu    = "200m"
      memory = "128Mi"
    },
    trivy = {
      cpu    = "200m"
      memory = "128Mi"
    }
  }
}

variable "resources_requests" {
  description = "Resource requests for Harbor components"
  type = map(object({
    cpu    = string
    memory = string
  }))
  default = {
    core = {
      cpu    = "300m"
      memory = "64Mi"
    },
    jobservice = {
      cpu    = "100m"
      memory = "64Mi"
    },
    registry = {
      cpu    = "100m"
      memory = "64Mi"
    },
    portal = {
      cpu    = "100m"
      memory = "64Mi"
    },
    trivy = {
      cpu    = "100m"
      memory = "64Mi"
    }
  }
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
