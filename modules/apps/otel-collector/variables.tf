variable "namespace" {
  description = "Kubernetes namespace for OpenTelemetry Collector"
  type        = string
  default     = "observability"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "opentelemetry-collector"
}

variable "chart_version" {
  description = "OpenTelemetry Collector Helm chart version"
  type        = string
  default     = "0.62.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "mode" {
  description = "Deployment mode for the collector (deployment, daemonset, or statefulset)"
  type        = string
  default     = "deployment"
}

variable "logs_collection" {
  description = "Enable logs collection"
  type        = bool
  default     = false
}

# OTLP protocol settings
variable "otlp_enabled" {
  description = "Enable OTLP/gRPC receiver"
  type        = bool
  default     = true
}

variable "otlp_port" {
  description = "Port for OTLP/gRPC receiver"
  type        = number
  default     = 4317
}

variable "otlp_http_enabled" {
  description = "Enable OTLP/HTTP receiver"
  type        = bool
  default     = true
}

variable "otlp_http_port" {
  description = "Port for OTLP/HTTP receiver"
  type        = number
  default     = 4318
}

# Exporters configuration
variable "exporters_endpoint" {
  description = "Endpoint to export telemetry data to"
  type        = string
  default     = "https://otel-collector.fullstack.pw"
}

variable "tls_insecure" {
  description = "Skip TLS verification for exporters"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Log level for the collector"
  type        = string
  default     = "debug"
}

# Resources
variable "memory_limit" {
  description = "Memory limit for the collector"
  type        = string
  default     = "256Mi"
}

variable "cpu_limit" {
  description = "CPU limit for the collector"
  type        = string
  default     = "200m"
}

variable "memory_request" {
  description = "Memory request for the collector"
  type        = string
  default     = "128Mi"
}

variable "cpu_request" {
  description = "CPU request for the collector"
  type        = string
  default     = "100m"
}

# Ingress configuration
variable "ingress_enabled" {
  description = "Enable ingress for the collector"
  type        = bool
  default     = false
}

variable "ingress_host" {
  description = "Hostname for the collector ingress"
  type        = string
  default     = "otel-collector.fullstack.pw"
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "ingress_tls_enabled" {
  description = "Enable TLS for the collector ingress"
  type        = bool
  default     = true
}

variable "ingress_tls_secret_name" {
  description = "TLS secret name for the collector ingress"
  type        = string
  default     = "otel-collector-tls"
}

variable "ingress_annotations" {
  description = "Annotations for the collector ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "otel-collector.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
    "kubernetes.io/ingress.class"               = "traefik"
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
