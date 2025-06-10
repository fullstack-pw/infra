variable "namespace" {
  description = "Kubernetes namespace for KubeVirt (must match operator namespace)"
  type        = string
  default     = "kubevirt"
}

variable "create_kubevirt_cr" {
  description = "Whether to create the KubeVirt CR"
  type        = bool
  default     = true
}

variable "create_cdi_cr" {
  description = "Whether to create the CDI CR"
  type        = bool
  default     = true
}

variable "kubevirt_feature_gates" {
  description = "List of feature gates to enable in KubeVirt"
  type        = list(string)
  default     = ["Snapshot", "VMExport"]
}

variable "cdi_feature_gates" {
  description = "List of feature gates to enable in CDI"
  type        = list(string)
  default     = ["HonorWaitForFirstConsumer"]
}

variable "enable_cdi_uploadproxy_ingress" {
  description = "Enable ingress for CDI upload proxy"
  type        = bool
  default     = false
}

variable "cdi_uploadproxy_host" {
  description = "Hostname for CDI upload proxy ingress"
  type        = string
  default     = "cdi-uploadproxy.fullstack.pw"
}

variable "virt_exportproxy_host" {
  description = "Hostname for kubevirt export proxy ingress"
  type        = string
  default     = "kubevirt-exportproxy.fullstack.pw"
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "traefik"
}

variable "cdi_uploadproxy_ingress_annotations" {
  description = "Additional annotations for CDI upload proxy ingress"
  type        = map(string)
  default     = {}
}
