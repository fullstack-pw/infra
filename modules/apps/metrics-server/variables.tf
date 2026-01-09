variable "namespace" {
  description = "Kubernetes namespace for metrics-server"
  type        = string
  default     = "kube-system"
}

variable "chart_version" {
  description = "Helm chart version for metrics-server"
  type        = string
  default     = "3.12.2"
}

variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor for metrics scraping"
  type        = bool
  default     = false
}
