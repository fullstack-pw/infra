variable "namespace" {
  description = "Kubernetes namespace to deploy ExternalDNS"
  type        = string
  default     = "default"
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
  default     = "pihole-password"
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

// modules/externaldns/outputs.tf
output "service_account_name" {
  description = "Name of the ExternalDNS service account"
  value       = kubernetes_service_account.externaldns.metadata[0].name
}

output "deployment_name" {
  description = "Name of the ExternalDNS deployment"
  value       = kubernetes_deployment.externaldns.metadata[0].name
}
