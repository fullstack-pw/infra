variable "namespace" {
  type    = string
  default = "falco"
}

variable "create_namespace" {
  type    = bool
  default = true
}

variable "chart_version" {
  type    = string
  default = "8.0.0"
}

variable "timeout" {
  type    = number
  default = 600
}

variable "driver_kind" {
  type    = string
  default = "modern_ebpf"
}

variable "memory_limit" {
  type    = string
  default = "512Mi"
}

variable "cpu_limit" {
  type    = string
  default = "500m"
}

variable "memory_request" {
  type    = string
  default = "128Mi"
}

variable "cpu_request" {
  type    = string
  default = "100m"
}

variable "enable_metrics" {
  type    = bool
  default = true
}
