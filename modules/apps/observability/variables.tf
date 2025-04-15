variable "namespace" {
  description = "Kubernetes namespace for observability stack"
  type        = string
  default     = "observability"
}

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

variable "loki_enabled" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "loki_chart_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "6.28.0"
}

variable "loki_domain" {
  description = "Domain name for Loki ingress"
  type        = string
  default     = "loki.fullstack.pw"
}

variable "loki_storage_type" {
  description = "Storage type for Loki (filesystem, s3, gcs, etc)"
  type        = string
  default     = "filesystem"
}

variable "loki_retention_period" {
  description = "Retention period for logs in Loki"
  type        = string
  default     = "168h"
}

variable "loki_persistence_enabled" {
  description = "Enable persistence for Loki"
  type        = bool
  default     = true
}

variable "loki_persistence_size" {
  description = "Size of the persistence volume for Loki"
  type        = string
  default     = "10Gi"
}

variable "loki_persistence_storage_class" {
  description = "Storage class for Loki persistence"
  type        = string
  default     = "local-path"
}

variable "loki_replicas" {
  description = "Number of Loki replicas in single binary mode"
  type        = number
  default     = 1
}

variable "loki_memory_request" {
  description = "Memory request for Loki"
  type        = string
  default     = "256Mi"
}

variable "loki_cpu_request" {
  description = "CPU request for Loki"
  type        = string
  default     = "100m"
}

variable "loki_memory_limit" {
  description = "Memory limit for Loki"
  type        = string
  default     = "512Mi"
}

variable "loki_cpu_limit" {
  description = "CPU limit for Loki"
  type        = string
  default     = "200m"
}

variable "promtail_enabled" {
  description = "Enable Promtail for log collection"
  type        = bool
  default     = false
}

variable "loki_service_monitor_enabled" {
  description = "Enable ServiceMonitor for Loki"
  type        = bool
  default     = true
}

variable "install_crd" {
  type    = bool
  default = false
}

variable "deployment_mode" {
  type    = string
  default = "SingleBinary"
}

variable "minio_enabled" {
  type    = bool
  default = true
}
variable "minio_rootUser" {
  type    = string
  default = "rootuser"
}
variable "minio_rootPassword" {
  type    = string
  default = "rootpass123"
}
variable "minio_address" {
  type    = string
  default = "s3.fullstack.pw"
}
