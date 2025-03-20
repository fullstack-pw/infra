output "namespace" {
  description = "Namespace where cert-manager is installed"
  value       = module.namespace.name
}

output "cluster_issuer" {
  description = "Name of the ClusterIssuer"
  value       = var.cluster_issuer
}

output "chart_version" {
  description = "Version of the deployed cert-manager chart"
  value       = var.chart_version
}

output "acme_server" {
  description = "ACME server URL"
  value       = var.acme_server
}

output "cloudflare_secret_name" {
  description = "Name of the Cloudflare API token secret"
  value       = module.cloudflare_secret.name
}
