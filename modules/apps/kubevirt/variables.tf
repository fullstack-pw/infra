variable "namespace" {
  description = "Kubernetes namespace for KubeVirt"
  type        = string
  default     = "kubevirt"
}

variable "namespace_labels" {
  description = "Labels to apply to the namespace"
  type        = map(string)
  default     = {}
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "create_kubevirt_cr" {
  description = "Whether to create the KubeVirt CR after installing the operator"
  type        = bool
  default     = true
}

variable "create_cdi_cr" {
  description = "Whether to create the KubeVirt CR after installing the operator"
  type        = bool
  default     = true
}
