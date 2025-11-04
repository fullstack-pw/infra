variable "namespace" {
  description = "Namespace for Istio system components"
  type        = string
  default     = "istio-system"
}

variable "istio_version" {
  description = "Istio version to install"
  type        = string
  default     = "1.24.2"
}

variable "pilot_replicas" {
  description = "Number of istiod replicas"
  type        = number
  default     = 1
}

variable "gateway_replicas" {
  description = "Number of ingress gateway replicas"
  type        = number
  default     = 1
}

variable "gateway_service_type" {
  description = "Service type for ingress gateway (LoadBalancer, NodePort, ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "gateway_load_balancer_ip" {
  description = "Static IP for LoadBalancer (optional)"
  type        = string
  default     = ""
}

variable "gateway_node_port_http" {
  description = "NodePort for HTTP traffic (only used if service_type is NodePort)"
  type        = number
  default     = 30080
}

variable "gateway_node_port_https" {
  description = "NodePort for HTTPS traffic (only used if service_type is NodePort)"
  type        = number
  default     = 30443
}

variable "enable_telemetry" {
  description = "Enable Istio telemetry (metrics, traces, logs)"
  type        = bool
  default     = true
}

variable "access_log_file" {
  description = "Path to access log file (/dev/stdout for console output, empty to disable)"
  type        = string
  default     = "/dev/stdout"
}

variable "enable_tracing" {
  description = "Enable distributed tracing"
  type        = bool
  default     = false
}

variable "tracing_endpoint" {
  description = "Jaeger/OTEL collector endpoint for traces"
  type        = string
  default     = ""
}

variable "create_default_gateway" {
  description = "Create a default Gateway resource for all hosts"
  type        = bool
  default     = true
}

variable "default_tls_secret" {
  description = "Default TLS secret name for the default gateway"
  type        = string
  default     = "default-gateway-tls"
}

variable "cert_issuer_name" {
  description = "Cert-manager issuer name for TLS certificates"
  type        = string
  default     = "letsencrypt-prod"
}

variable "cert_issuer_kind" {
  description = "Cert-manager issuer kind (ClusterIssuer or Issuer)"
  type        = string
  default     = "ClusterIssuer"
}

variable "gateway_dns_names" {
  description = "DNS names for the default gateway TLS certificate"
  type        = list(string)
  default     = []
}
