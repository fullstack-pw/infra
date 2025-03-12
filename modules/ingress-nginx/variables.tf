variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "nginx-ingress"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy ingress-nginx"
  type        = string
  default     = "default"
}

variable "chart_version" {
  description = "Nginx ingress controller Helm chart version"
  type        = string
  default     = "1.2.0"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 600
}

variable "atomic" {
  description = "Purge resources on installation failure"
  type        = bool
  default     = true
}

variable "enable_custom_resources" {
  description = "Enable custom resources support in nginx controller"
  type        = bool
  default     = true
}

variable "enable_snippets" {
  description = "Enable snippets support in nginx controller"
  type        = bool
  default     = true
}

variable "default_tls_secret" {
  description = "Default TLS secret for the ingress controller"
  type        = string
  default     = ""
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
