variable "enabled" {
  description = "Enable PVC creation"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the PVC"
  type        = string
}

variable "namespace" {
  description = "Namespace for the PVC"
  type        = string
}

variable "access_modes" {
  description = "Access modes for the PVC"
  type        = list(string)
  default     = ["ReadWriteOnce"]
}

variable "storage_class" {
  description = "Storage class for the PVC"
  type        = string
  default     = "local-path"
}

variable "size" {
  description = "Size of the PVC"
  type        = string
  default     = "1Gi"
}

variable "labels" {
  description = "Labels for the PVC"
  type        = map(string)
  default     = {}
}

variable "selector_labels" {
  description = "Selector labels for PVC"
  type        = map(string)
  default     = {}
}
