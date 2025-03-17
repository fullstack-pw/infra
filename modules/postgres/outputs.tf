output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.postgres.name
}

output "namespace" {
  description = "Namespace of the deployed PostgreSQL"
  value       = helm_release.postgres.namespace
}

output "version" {
  description = "Version of the deployed PostgreSQL"
  value       = var.postgres_version
}

output "postgres_host" {
  description = "PostgreSQL service hostname"
  value       = "${var.release_name}-postgresql.${local.namespace}.svc.cluster.local"
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
  value       = local.postgres_password
  sensitive   = true
}

output "postgres_database" {
  description = "PostgreSQL default database"
  value       = local.postgres_database
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${local.postgres_username}:${local.postgres_password}@${var.release_name}-postgresql.${local.namespace}.svc.cluster.local:${var.service_port}/${local.postgres_database}"
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing PostgreSQL credentials"
  value       = var.generate_credentials && var.create_credentials_secret ? kubernetes_secret.postgres_credentials[0].metadata[0].name : null
}

output "metrics_enabled" {
  description = "Whether metrics are enabled for PostgreSQL"
  value       = var.enable_metrics
}

output "service_name" {
  description = "Name of the PostgreSQL service"
  value       = "${var.release_name}-postgresql"
}
