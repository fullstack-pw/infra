variable "enabled" {
  description = "Enable gateway creation"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the gateway"
  type        = string
}

variable "namespace" {
  description = "Namespace for the gateway"
  type        = string
}

variable "hosts" {
  description = "List of hosts for the gateway"
  type        = list(string)
}

variable "selector" {
  description = "Label selector for the gateway (typically selects ingress gateway pods)"
  type        = map(string)
  default = {
    istio = "ingressgateway"
  }
}

variable "http_enabled" {
  description = "Enable HTTP (port 80) on the gateway"
  type        = bool
  default     = true
}

variable "https_enabled" {
  description = "Enable HTTPS (port 443) on the gateway"
  type        = bool
  default     = true
}

variable "https_redirect" {
  description = "Redirect HTTP to HTTPS"
  type        = bool
  default     = true
}

variable "tls_mode" {
  description = "TLS mode (SIMPLE, MUTUAL, PASSTHROUGH, ISTIO_MUTUAL)"
  type        = string
  default     = "SIMPLE"
}

variable "tls_secret_name" {
  description = "Name of the TLS secret (auto-generated from first host if not provided)"
  type        = string
  default     = ""
}

variable "tls_min_version" {
  description = "Minimum TLS version (TLSV1_2, TLSV1_3)"
  type        = string
  default     = "TLSV1_2"
}

variable "additional_servers" {
  description = "Additional custom server configurations"
  type = list(object({
    port = object({
      number   = number
      name     = string
      protocol = string
    })
    hosts = list(string)
    tls   = optional(map(any))
  }))
  default = []
}

variable "annotations" {
  description = "Additional annotations for the gateway"
  type        = map(string)
  default     = {}
}

variable "default_annotations" {
  description = "Add default annotations (external-dns)"
  type        = bool
  default     = true
}
