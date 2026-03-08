variable "namespace" {
  description = "Namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "chart_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.2"
}

variable "cluster_issuer" {
  description = "Name of the ClusterIssuer"
  type        = string
  default     = "letsencrypt-prod"
}

variable "acme_server" {
  description = "ACME server URL"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "email" {
  description = "Email for ACME registration"
  type        = string
  default     = "pedropilla@gmail.com"
}

variable "install_crd" {
  description = "Whether to install cert-manager CRDs"
  type        = bool
  default     = true
}

variable "issuer_type" {
  description = "Type of ClusterIssuer to create: acme or selfsigned"
  type        = string
  default     = "selfsigned"

  validation {
    condition     = contains(["acme", "selfsigned"], var.issuer_type)
    error_message = "issuer_type must be 'acme' or 'selfsigned'"
  }
}

variable "cloudflare_secret" {
  description = "CloudFlare secret"
  type        = string
  sensitive   = true
  default     = ""
}
