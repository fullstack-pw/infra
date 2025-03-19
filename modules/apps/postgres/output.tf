output "release_name" {
  description = "Name of the Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace of the deployed PostgreSQL"
  value       = module.namespace.name
}

output "version" {
  description = "Version of the deployed PostgreSQL"
  value       = var.postgres_version
}

output "postgres_host" {
  description = "PostgreSQL service hostname"
  value       = "${var.release_name}-postgresql.${module.namespace.name}.svc.cluster.local"
}

output "postgres_port" {
  description = "PostgreSQL service port"
  value       = var.service_port
}

output "postgres_username" {
  description = "PostgreSQL admin username"
  value       = local.postgres_username
  sensitive   = true
}

output "postgres_password" {
  description = "PostgreSQL admin password"
  value       = module.credentials.password
  sensitive   = true
}

output "postgres_database" {
  description = "PostgreSQL default database"
  value       = local.postgres_database
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${local.postgres_username}:${module.credentials.password}@${var.release_name}-postgresql.${module.namespace.name}.svc.cluster.local:${var.service_port}/${local.postgres_database}"
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing PostgreSQL credentials"
  value       = var.generate_credentials && var.create_credentials_secret ? module.credentials.name : null
}

output "metrics_enabled" {
  description = "Whether metrics are enabled for PostgreSQL"
  value       = var.enable_metrics
}

output "service_name" {
  description = "Name of the PostgreSQL service"
  value       = "${var.release_name}-postgresql"
}

output "ingress_host" {
  description = "Hostname for PostgreSQL ingress (if ingress is enabled)"
  value       = var.ingress_enabled ? module.ingress.host : null
}

output "ingress_url" {
  description = "URL for PostgreSQL ingress (if ingress is enabled)"
  value       = var.ingress_enabled ? module.ingress.url : null
}
