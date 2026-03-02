variable "namespace" {
  description = "Kubernetes namespace for Gitea"
  type        = string
  default     = "gitea"
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "gitea"
}

variable "chart_version" {
  description = "Gitea Helm chart version"
  type        = string
  default     = "10.6.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "domain" {
  description = "Domain for Gitea"
  type        = string
  default     = "git.fullstack.pw"
}

variable "ssh_domain" {
  description = "Domain for Gitea SSH access"
  type        = string
  default     = "git.fullstack.pw"
}

variable "ssh_port" {
  description = "NodePort for SSH access"
  type        = number
  default     = 2222
}

variable "admin_username" {
  description = "Gitea admin username"
  type        = string
  default     = "gitea-admin"
}

variable "admin_password" {
  description = "Gitea admin password"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Gitea admin email"
  type        = string
  default     = "admin@fullstack.pw"
}

variable "secret_key" {
  description = "Gitea secret key for session/cookie signing"
  type        = string
  sensitive   = true
}

variable "internal_token" {
  description = "Gitea internal API token"
  type        = string
  sensitive   = true
}

variable "external_database_host" {
  description = "External PostgreSQL host"
  type        = string
  default     = "postgres-rw.default.svc.cluster.local"
}

variable "external_database_port" {
  description = "External PostgreSQL port"
  type        = number
  default     = 5432
}

variable "external_database_name" {
  description = "PostgreSQL database name for Gitea"
  type        = string
  default     = "gitea"
}

variable "external_database_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "external_database_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "external_database_ssl_mode" {
  description = "PostgreSQL SSL mode"
  type        = string
  default     = "disable"
}

variable "external_redis_host" {
  description = "External Redis host"
  type        = string
  default     = "redis-master.default.svc.cluster.local"
}

variable "external_redis_port" {
  description = "External Redis port"
  type        = number
  default     = 6379
}

variable "external_redis_password" {
  description = "External Redis password"
  type        = string
  sensitive   = true
}

variable "ingress_enabled" {
  description = "Enable ingress for Gitea"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_annotations" {
  description = "Annotations for Gitea ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "git.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
}

variable "storage_class" {
  description = "Storage class for Gitea persistent volumes"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Size of the Gitea data persistent volume"
  type        = string
  default     = "10Gi"
}

variable "default_actions_url" {
  description = "Default URL for Gitea Actions (set to self for full air-gap)"
  type        = string
  default     = "https://git.fullstack.pw"
}

variable "additional_set_values" {
  description = "Additional Helm set values"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
