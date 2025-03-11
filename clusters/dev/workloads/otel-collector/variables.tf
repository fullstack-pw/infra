variable "namespace" {
  description = "Kubernetes namespace for observability stack"
  type        = string
  default     = "observability"
}

variable "collector_endpoint" {
  description = "Endpoint for the upstream OpenTelemetry collector"
  type        = string
  default     = "otel-collector.fullstack.pw:443"
}