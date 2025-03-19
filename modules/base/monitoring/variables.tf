variable "name" {
  description = "Name to use for the monitoring resources"
  type        = string
}

variable "namespace" {
  description = "Namespace where resources will be created"
  type        = string
}

variable "labels" {
  description = "Labels to apply to monitoring resources"
  type        = map(string)
  default     = {}
}

variable "selector_labels" {
  description = "Labels for service/pod selection"
  type        = map(string)
  default     = {}
}

# ServiceMonitor related variables
variable "create_service_monitor" {
  description = "Whether to create a ServiceMonitor resource"
  type        = bool
  default     = false
}

variable "endpoints" {
  description = "List of endpoints for ServiceMonitor"
  type        = list(any)
  default     = []
}

# PodMonitor related variables
variable "create_pod_monitor" {
  description = "Whether to create a PodMonitor resource"
  type        = bool
  default     = false
}

variable "pod_metrics_endpoints" {
  description = "Pod metric endpoints configuration"
  type        = list(any)
  default     = []
}

# PrometheusRule related variables
variable "create_prometheus_rule" {
  description = "Whether to create a PrometheusRule resource"
  type        = bool
  default     = false
}

variable "rule_groups" {
  description = "Rule groups for PrometheusRule"
  type        = list(any)
  default     = []
}
