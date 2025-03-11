variable "vault_token" {
  description = "Vault token for authentication"
  type        = string
  sensitive   = true
}

variable "namespace" {
  description = "Kubernetes namespace for observability stack"
  type        = string
  default     = "observability"
}

variable "jaeger_storage_type" {
  description = "Jaeger storage type (memory, elasticsearch, cassandra)"
  type        = string
  default     = "memory"  # Start with memory for simplicity
}

variable "retention_days" {
  description = "Number of days to retain traces"
  type        = number
  default     = 7
}

variable "otel_collector_replicas" {
  description = "Number of OpenTelemetry collector replicas"
  type        = number
  default     = 2
}