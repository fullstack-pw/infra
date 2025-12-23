variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"
}

variable "chart_version" {
  description = "Helm chart version for MetalLB"
  type        = string
  default     = "0.14.9"
}

variable "create_ip_pool" {
  description = "Whether to create IPAddressPool and L2Advertisement resources"
  type        = bool
  default     = false
}

variable "ip_pool_name" {
  description = "Name of the IPAddressPool"
  type        = string
  default     = "default-pool"
}

variable "ip_pool_addresses" {
  description = "List of IP address ranges for the pool (e.g., ['192.168.1.100-192.168.1.110'])"
  type        = list(string)
  default     = []
}

variable "l2_advertisement_name" {
  description = "Name of the L2Advertisement"
  type        = string
  default     = "default-l2"
}
