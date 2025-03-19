variable "namespace" {
  description = "Kubernetes namespace for observability stack"
  type        = string
  default     = "observability"
}

# OpenTelemetry Operator
variable "opentelemetry_operator_version" {
  description = "Version of the OpenTelemetry Operator Helm chart"
  type        = string
  default     = "0.33.0"
}

variable "admission_webhooks_enabled" {
  description = "Enable admission webhooks for OpenTelemetry Operator"
  type        = bool
  default     = true
}

variable "cert_manager_enabled" {
  description = "Enable cert-manager integration for OpenTelemetry Operator"
  type        = bool
  default     = true
}

# Jaeger Operator
variable "jaeger_operator_version" {
  description = "Version of the Jaeger Operator Helm chart"
  type        = string
  default     = "2.57.0"
}

variable "jaeger_rbac_cluster_role" {
  description = "Use cluster role for Jaeger Operator RBAC"
  type        = bool
  default     = true
}

# Jaeger Instance
variable "jaeger_instance_name" {
  description = "Name of the Jaeger instance"
  type        = string
  default     = "jaeger"
}

variable "jaeger_storage_type" {
  description = "Jaeger storage type (memory, elasticsearch, cassandra)"
  type        = string
  default     = "memory"
  validation {
    condition     = contains(["memory", "elasticsearch", "cassandra"], var.jaeger_storage_type)
    error_message = "Jaeger storage type must be one of: memory, elasticsearch, cassandra."
  }
}

variable "elasticsearch_url" {
  description = "Elasticsearch URL for Jaeger storage (required if jaeger_storage_type is elasticsearch)"
  type        = string
  default     = "http://elasticsearch:9200"
}

variable "jaeger_domain" {
  description = "Domain name for Jaeger UI ingress"
  type        = string
  default     = "jaeger.fullstack.pw"
}

variable "jaeger_ingress_annotations" {
  description = "Additional annotations for Jaeger ingress"
  type        = map(string)
  default     = { "nginx.ingress.kubernetes.io/proxy-body-size" = "0" }
}

# OpenTelemetry Collector
variable "otel_collector_name" {
  description = "Name of the OpenTelemetry Collector"
  type        = string
  default     = "otel-collector"
}

variable "otel_collector_replicas" {
  description = "Number of OpenTelemetry collector replicas"
  type        = number
  default     = 2
}

variable "otel_collector_domain" {
  description = "Domain name for OpenTelemetry Collector ingress"
  type        = string
  default     = "otel-collector.fullstack.pw"
}

variable "otel_collector_ingress_annotations" {
  description = "Additional annotations for OpenTelemetry Collector ingress"
  type        = map(string)
  default     = {}
}

# Common
variable "ingress_class_name" {
  description = "Ingress class name to use for all ingresses"
  type        = string
  default     = "nginx"
}

variable "cert_manager_cluster_issuer" {
  description = "cert-manager cluster issuer to use for TLS certificates"
  type        = string
  default     = "letsencrypt-prod"
}

variable "prometheus_enabled" {
  description = "Enable Prometheus stack deployment"
  type        = bool
  default     = true
}

variable "prometheus_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "69.8.2"
}

variable "prometheus_values_file" {
  description = "Path to custom values file for Prometheus"
  type        = string
  default     = ""
}

variable "prometheus_domain" {
  description = "Domain name for Prometheus UI ingress"
  type        = string
  default     = "prometheus.fullstack.pw"
}

variable "prometheus_ingress_annotations" {
  description = "Additional annotations for Prometheus ingress"
  type        = map(string)
  default     = {}
}

variable "grafana_domain" {
  description = "Domain name for Grafana UI ingress"
  type        = string
  default     = "grafana.fullstack.pw"
}

variable "grafana_ingress_annotations" {
  description = "Additional annotations for Grafana ingress"
  type        = map(string)
  default     = {}
}
