variable "namespace" {
  type    = string
  default = "observability"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "otel_collector_release_name" {
  type    = string
  default = "opentelemetry-collector"
}

variable "otel_collector_chart_version" {
  type    = string
  default = "0.62.0"
}

variable "otel_collector_timeout" {
  type    = number
  default = 300
}

variable "otel_collector_mode" {
  type    = string
  default = "deployment"
}

variable "otel_collector_logs_collection" {
  type    = bool
  default = false
}

variable "otel_collector_otlp_enabled" {
  type    = bool
  default = true
}

variable "otel_collector_otlp_port" {
  type    = number
  default = 4317
}

variable "otel_collector_otlp_http_enabled" {
  type    = bool
  default = true
}

variable "otel_collector_otlp_http_port" {
  type    = number
  default = 4318
}

variable "otel_collector_exporters_endpoint" {
  type    = string
  default = "https://otel-collector.fullstack.pw"
}

variable "otel_collector_tls_insecure" {
  type    = bool
  default = false
}

variable "otel_collector_log_level" {
  type    = string
  default = "warn"
}

variable "otel_collector_memory_limit" {
  type    = string
  default = "256Mi"
}

variable "otel_collector_cpu_limit" {
  type    = string
  default = "200m"
}

variable "otel_collector_memory_request" {
  type    = string
  default = "128Mi"
}

variable "otel_collector_cpu_request" {
  type    = string
  default = "100m"
}

variable "otel_collector_additional_set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "fluent_release_name" {
  type    = string
  default = "fluent"
}

variable "fluent_chart_version" {
  type    = string
  default = "0.48.9"
}

variable "fluent_force_update" {
  type    = bool
  default = false
}

variable "fluent_timeout" {
  type    = number
  default = 300
}

variable "fluent_additional_set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}


variable "prometheus_release_name" {
  type    = string
  default = "prometheus"
}

variable "prometheus_chart_version" {
  type    = string
  default = "27.45.0"
}

variable "prometheus_remote_write_url" {
  type    = string
  default = "https://prometheus.fullstack.pw/api/v1/write"
}

variable "prometheus_force_update" {
  type    = bool
  default = false
}

variable "prometheus_timeout" {
  type    = number
  default = 300
}

variable "prometheus_additional_set_values" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "prometheus_memory_limit" {
  type    = string
  default = "1024Mi"
}

variable "prometheus_cpu_limit" {
  type    = string
  default = "4000m"
}

variable "prometheus_memory_request" {
  type    = string
  default = "128Mi"
}

variable "prometheus_cpu_request" {
  type    = string
  default = "100m"
}

variable "prometheus_namespaces" {
  type        = list(string)
  default     = []
  description = "List of namespaces to exclude from metric collection. Metrics from pods and services in these namespaces will be dropped."
}
