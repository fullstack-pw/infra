variable "namespace" {
  description = "Namespace for cluster-autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "create_namespace" {
  description = "Whether to create the namespace"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Helm chart version for cluster-autoscaler"
  type        = string
  default     = "9.54.0"
}

variable "image_tag" {
  description = "Cluster autoscaler image tag"
  type        = string
  default     = "v1.34.2"
}

variable "managed_clusters" {
  description = "List of workload clusters to manage"
  type = list(object({
    name      = string
    namespace = string
  }))
}

variable "scale_down_enabled" {
  description = "Enable node scale down"
  type        = bool
  default     = true
}

variable "scale_down_delay_after_add" {
  description = "Delay before scale down after node addition"
  type        = string
  default     = "10m"
}

variable "scale_down_unneeded_time" {
  description = "Time a node must be unneeded before scale down"
  type        = string
  default     = "10m"
}

variable "skip_nodes_with_local_storage" {
  description = "Skip nodes with local storage during scale down"
  type        = bool
  default     = false
}

variable "skip_nodes_with_system_pods" {
  description = "Skip nodes with system pods during scale down"
  type        = bool
  default     = true
}

variable "balance_similar_node_groups" {
  description = "Balance similar node groups"
  type        = bool
  default     = true
}

variable "expander" {
  description = "Node group selection strategy"
  type        = string
  default     = "least-waste"
}

variable "replicas" {
  description = "Number of autoscaler replicas"
  type        = number
  default     = 1
}

variable "additional_set_values" {
  description = "Additional Helm values to set"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
