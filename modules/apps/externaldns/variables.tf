variable "namespace" {
  description = "Kubernetes namespace to deploy ExternalDNS"
  type        = string
  default     = "external-dns"
}

variable "create_namespace" {
  type    = bool
  default = true

}
variable "replicas" {
  description = "Number of ExternalDNS replicas"
  type        = number
  default     = 1
}

variable "image" {
  description = "ExternalDNS container image"
  type        = string
  default     = "registry.k8s.io/external-dns/external-dns:v0.14.1"
}

variable "pihole_secret_name" {
  description = "Name of the secret containing PiHole credentials"
  type        = string
  default     = "cluster-secrets"
}

variable "container_args" {
  description = "Arguments to pass to the ExternalDNS container"
  type        = list(string)
  default = [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--registry=noop",
    "--policy=upsert-only",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3",
  ]
}

variable "create_pihole_secret" {
  description = "Whether to create a secret for PiHole password"
  type        = bool
  default     = false
}

variable "pihole_password" {
  description = "Password for the PiHole API"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dns_provider" {
  description = "DNS provider to use (pihole or cloudflare)"
  type        = string
  default     = "pihole"
  validation {
    condition     = contains(["pihole", "cloudflare"], var.dns_provider)
    error_message = "Provider must be either 'pihole' or 'cloudflare'."
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_secret_name" {
  description = "Name of the secret containing Cloudflare API token"
  type        = string
  default     = "cloudflare-api-token"
}

variable "create_cloudflare_secret" {
  description = "Whether to create a secret for Cloudflare API token"
  type        = bool
  default     = false
}

variable "deployment_name" {
  description = "Name of the ExternalDNS deployment (allows multiple instances)"
  type        = string
  default     = "external-dns"
}
