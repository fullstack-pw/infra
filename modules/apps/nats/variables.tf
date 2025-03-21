variable "namespace" {
  description = "Kubernetes namespace for NATS"
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
  default     = "nats"
}

variable "chart_version" {
  description = "NATS Helm chart version"
  type        = string
  default     = "1.2.11"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "cluster_name" {
  description = "Name of the NATS cluster"
  type        = string
  default     = "nats-cluster"
}

# Authentication
variable "auth_enabled" {
  description = "Enable basic authentication"
  type        = bool
  default     = true
}

variable "generate_password" {
  description = "Generate random password for NATS user"
  type        = bool
  default     = true
}

variable "nats_user" {
  description = "Username for NATS authentication"
  type        = string
  default     = "nats"
}

variable "nats_password" {
  description = "Password for NATS authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth_token_enabled" {
  description = "Enable token-based authentication"
  type        = bool
  default     = false
}

variable "generate_auth_token" {
  description = "Generate random token for authentication"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Token for NATS authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_credentials_secret" {
  description = "Create a Kubernetes secret with NATS credentials"
  type        = bool
  default     = true
}

# JetStream
variable "jetstream_enabled" {
  description = "Enable JetStream"
  type        = bool
  default     = true
}

# Persistence
variable "persistence_enabled" {
  description = "Enable persistence for JetStream"
  type        = bool
  default     = true
}

variable "persistence_storage_class" {
  description = "Storage class for persistence"
  type        = string
  default     = "local-path"
}

variable "persistence_size" {
  description = "Size of the persistence volume"
  type        = string
  default     = "2Gi"
}

# Scalability
variable "replicas" {
  description = "Number of NATS server replicas"
  type        = number
  default     = 3
}

# Resources
variable "memory_request" {
  description = "Memory request for NATS pods"
  type        = string
  default     = "256Mi"
}

variable "cpu_request" {
  description = "CPU request for NATS pods"
  type        = string
  default     = "100m"
}

variable "memory_limit" {
  description = "Memory limit for NATS pods"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU limit for NATS pods"
  type        = string
  default     = "200m"
}

# Monitoring
variable "prometheus_enabled" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = false
}

variable "prometheus_port" {
  description = "Port for Prometheus metrics"
  type        = number
  default     = 7777
}

variable "monitoring_enabled" {
  description = "Enable NATS monitoring interface"
  type        = bool
  default     = true
}

# Networking
variable "service_type" {
  description = "Type of Kubernetes service"
  type        = string
  default     = "LoadBalancer"
}

variable "nats_port" {
  description = "Port for NATS service"
  type        = number
  default     = 4222
}

variable "websocket_enabled" {
  description = "Enable WebSocket support"
  type        = bool
  default     = true
}

variable "websocket_port" {
  description = "Port for WebSocket connections"
  type        = number
  default     = 8080
}

# Ingress
variable "ingress_enabled" {
  description = "Enable ingress for NATS monitoring"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_host" {
  description = "Hostname for NATS monitoring ingress"
  type        = string
  default     = "nats.fullstack.pw"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for NATS ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for NATS ingress"
  type        = string
  default     = "nats-tls"
}

variable "ingress_annotations" {
  description = "Additional annotations for NATS ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "nats.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
    "kubernetes.io/ingress.class"               = "traefik"
  }
}

variable "cert_manager_cluster_issuer" {
  description = "Name of the cert-manager ClusterIssuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
