variable "enabled" {
  description = "Enable ingress creation"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the ingress"
  type        = string
}

variable "namespace" {
  description = "Namespace for the ingress"
  type        = string
}

variable "host" {
  description = "Hostname for the ingress"
  type        = string
}

variable "service_name" {
  description = "Name of the service to route traffic to"
  type        = string
}

variable "service_port" {
  description = "Port of the service to route traffic to"
  type        = number
  default     = null
}

variable "service_port_name" {
  description = "Name of the service port to route traffic to"
  type        = string
  default     = null
}

variable "paths" {
  description = "List of paths to match for routing"
  type = list(object({
    path      = string
    path_type = string
    backend = object({
      service_name      = optional(string)
      service_port      = optional(number)
      service_port_name = optional(string)
    })
  }))
  default = []
}

variable "path" {
  description = "Path to match for routing (used when paths is empty)"
  type        = string
  default     = "/"
}

variable "path_type" {
  description = "Path type for routing (Exact, Prefix, or ImplementationSpecific)"
  type        = string
  default     = "Prefix"
}

variable "tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = true
}

variable "tls_secret_name" {
  description = "Name of the TLS secret"
  type        = string
  default     = ""
}

variable "ingress_class_name" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "cluster_issuer" {
  description = "Name of the cert-manager cluster issuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "annotations" {
  description = "Additional annotations for the ingress"
  type        = map(string)
  default     = {}
}

variable "default_annotations" {
  description = "Add default annotations (external-dns, cert-manager)"
  type        = bool
  default     = true
}
