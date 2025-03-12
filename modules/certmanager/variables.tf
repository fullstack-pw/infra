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
}

variable "vault_token" {
  description = "Vault token for authentication"
  type        = string
  sensitive   = true
}
