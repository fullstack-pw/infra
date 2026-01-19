output "namespace" {
  description = "Namespace where Authentik is deployed"
  value       = module.namespace.name
}

output "release_name" {
  description = "Name of the Helm release"
  value       = var.release_name
}

output "domain" {
  description = "Domain where Authentik is accessible"
  value       = var.domain
}

output "issuer_url" {
  description = "OIDC issuer URL base (append /application/o/<slug>/ for specific apps)"
  value       = "https://${var.domain}"
}
