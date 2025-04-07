output "namespace" {
  description = "Namespace where Harbor is deployed"
  value       = module.namespace.name
}

output "release_name" {
  description = "Name of the Harbor Helm release"
  value       = module.helm.name
}

output "harbor_url" {
  description = "URL to access Harbor"
  value       = "https://${var.harbor_domain}"
}

output "harbor_admin_username" {
  description = "Harbor admin username"
  value       = "admin"
}

output "harbor_admin_password" {
  description = "Harbor admin password"
  value       = local.admin_password
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing Harbor credentials"
  value       = module.credentials.name
}

output "version" {
  description = "Version of the deployed Harbor chart"
  value       = var.chart_version
}

output "external_database_host" {
  description = "External PostgreSQL host used by Harbor"
  value       = var.external_database_host
}

output "external_redis_host" {
  description = "External Redis host used by Harbor"
  value       = var.external_redis_host
}
