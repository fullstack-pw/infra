output "release_name" {
  description = "Name of the Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace of the deployed MinIO"
  value       = module.namespace.name
}

output "version" {
  description = "Version of the deployed MinIO chart"
  value       = var.chart_version
}

output "s3_endpoint" {
  description = "Endpoint URL for S3 API"
  value       = "https://${var.ingress_host}"
}

output "console_endpoint" {
  description = "Endpoint URL for MinIO Console"
  value       = "https://${var.console_ingress_host}"
}

output "root_user" {
  description = "MinIO root user"
  value       = local.root_user
  sensitive   = true
}

output "root_password" {
  description = "MinIO root password"
  value       = local.root_password
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing MinIO credentials"
  value       = var.generate_root_credentials && var.create_credentials_secret ? module.credentials.name : null
}
