variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "minio"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy MinIO"
  type        = string
  default     = "default"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "chart_version" {
  description = "MinIO Helm chart version"
  type        = string
  default     = "5.3.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "mode" {
  description = "MinIO deployment mode (standalone or distributed)"
  type        = string
  default     = "standalone"
  validation {
    condition     = contains(["standalone", "distributed"], var.mode)
    error_message = "Mode must be either 'standalone' or 'distributed'."
  }
}

# Root credentials
variable "generate_root_credentials" {
  description = "Generate random root credentials"
  type        = bool
  default     = false
}

variable "root_user" {
  description = "MinIO root user"
  type        = string
  default     = "rootuser"
}

variable "root_password" {
  description = "MinIO root password"
  type        = string
  default     = "rootpass123"
  sensitive   = true
}

variable "create_credentials_secret" {
  description = "Create a Kubernetes secret with the MinIO credentials"
  type        = bool
  default     = false
}

# Persistence
variable "persistence_enabled" {
  description = "Enable persistence for MinIO"
  type        = bool
  default     = true
}

variable "persistence_storage_class" {
  description = "Storage class for MinIO PVC"
  type        = string
  default     = "local-path"
}

variable "persistence_size" {
  description = "Size of the MinIO PVC"
  type        = string
  default     = "10Gi"
}

# Resources
variable "memory_request" {
  description = "Memory request for MinIO pods"
  type        = string
  default     = "256Mi"
}

# Ingress
variable "ingress_enabled" {
  description = "Enable ingress for MinIO API"
  type        = bool
  default     = true
}

variable "ingress_annotations" {
  description = "Annotations for the MinIO API ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname"   = "s3.fullstack.pw"
    "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
    "nginx.org/client-max-body-size"              = "0"
  }
}

variable "ingress_class_name" {
  description = "Ingress class name for MinIO API"
  type        = string
  default     = "nginx"
}

variable "ingress_host" {
  description = "Hostname for MinIO API ingress"
  type        = string
  default     = "s3.fullstack.pw"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for MinIO API ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for MinIO API ingress"
  type        = string
  default     = "minio-tls"
}

# Console Ingress
variable "console_ingress_enabled" {
  description = "Enable ingress for MinIO Console"
  type        = bool
  default     = true
}

variable "console_ingress_annotations" {
  description = "Annotations for the MinIO Console ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "minio.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
}

variable "console_ingress_class_name" {
  description = "Ingress class name for MinIO Console"
  type        = string
  default     = "nginx"
}

variable "console_ingress_host" {
  description = "Hostname for MinIO Console ingress"
  type        = string
  default     = "minio.fullstack.pw"
}

variable "console_ingress_tls_enabled" {
  description = "Enable TLS for MinIO Console ingress"
  type        = bool
  default     = true
}

variable "console_ingress_tls_secret_name" {
  description = "TLS secret name for MinIO Console ingress"
  type        = string
  default     = "minio-console-tls"
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
