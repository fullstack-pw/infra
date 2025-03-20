variable "release_name" {
  description = "Name of the Helm release"
  type        = string
}

variable "namespace" {
  description = "Namespace for the Helm release"
  type        = string
}

variable "repository" {
  description = "Helm chart repository URL"
  type        = string
}

variable "chart" {
  description = "Helm chart name"
  type        = string
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Timeout for Helm operations in seconds"
  type        = number
  default     = 300
}

variable "atomic" {
  description = "If set, installation will purge chart on fail and wait for resources to be deleted"
  type        = bool
  default     = false
}

variable "force_update" {
  type    = bool
  default = false
}

variable "values_files" {
  description = "List of values files to use for the Helm release"
  type        = list(string)
  default     = []
}

variable "set_values" {
  description = "Values to set on the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "set_sensitive_values" {
  description = "Sensitive values to set on the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default   = []
  sensitive = true
}
