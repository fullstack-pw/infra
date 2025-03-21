variable "namespace" {
  description = "Kubernetes namespace for Redis"
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
  default     = "redis"
}

variable "chart_version" {
  description = "Redis Helm chart version"
  type        = string
  default     = "17.14.4"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

# Credentials
variable "generate_password" {
  description = "Generate random password"
  type        = bool
  default     = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth_enabled" {
  description = "Enable Redis password authentication"
  type        = bool
  default     = true
}

variable "create_credentials_secret" {
  description = "Create a Kubernetes secret with the Redis credentials"
  type        = bool
  default     = true
}

# Persistence
variable "persistence_enabled" {
  description = "Enable persistence for Redis"
  type        = bool
  default     = true
}

variable "persistence_storage_class" {
  description = "Storage class for Redis PVC"
  type        = string
  default     = "local-path"
}

variable "persistence_size" {
  description = "Size of the Redis PVC"
  type        = string
  default     = "10Gi"
}

# Resources
variable "memory_request" {
  description = "Memory request for Redis pods"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request for Redis pods"
  type        = string
  default     = "200m"
}

variable "memory_limit" {
  description = "Memory limit for Redis pods"
  type        = string
  default     = "1Gi"
}

variable "cpu_limit" {
  description = "CPU limit for Redis pods"
  type        = string
  default     = "500m"
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
  description = "Redis service port"
  type        = number
  default     = 6379
}

# Ingress
variable "ingress_enabled" {
  description = "Enable ingress for Redis"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_host" {
  description = "Hostname for Redis ingress"
  type        = string
  default     = "redis.fullstack.pw"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for Redis ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for Redis ingress"
  type        = string
  default     = "redis-tls"
}

variable "ingress_annotations" {
  description = "Additional annotations for the Redis ingress"
  type        = map(string)
  default = {
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/service-upstream"      = "true"
  }
}

variable "cert_manager_cluster_issuer" {
  description = "Name of the cert-manager ClusterIssuer to use for TLS"
  type        = string
  default     = "letsencrypt-prod"
}

# High Availability
variable "sentinel_enabled" {
  description = "Enable Redis Sentinel for high availability"
  type        = bool
  default     = false
}

variable "sentinel_quorum" {
  description = "Sentinel quorum (number of Sentinels that need to agree to consider master down)"
  type        = number
  default     = 2
}

variable "replicas" {
  description = "Number of Redis replicas when using Sentinel"
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
