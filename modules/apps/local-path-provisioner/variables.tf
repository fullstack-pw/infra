variable "namespace" {
  description = "Kubernetes namespace for local-path-provisioner"
  type        = string
  default     = "local-path-storage"
}

variable "chart_version" {
  description = "Helm chart version for local-path-provisioner"
  type        = string
  default     = "0.0.30"
}

variable "storage_class_name" {
  description = "Name of the storage class to create"
  type        = string
  default     = "local-path"
}

variable "set_default_storage_class" {
  description = "Set this storage class as default"
  type        = bool
  default     = true
}
