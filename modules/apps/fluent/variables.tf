variable "namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "fluent"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "fluent"
}

variable "chart_version" {
  description = "Version of the Vault Helm chart"
  type        = string
  default     = "0.48.9"
}

variable "force_update" {
  description = "Force resource updates through replacement"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 60
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
