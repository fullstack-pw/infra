output "namespace" {
  description = "Namespace where Longhorn is installed"
  value       = module.namespace.name
}

output "release_name" {
  description = "Name of the Longhorn Helm release"
  value       = module.helm.name
}

output "chart_version" {
  description = "Version of the deployed Longhorn chart"
  value       = var.chart_version
}

output "ui_url" {
  description = "URL to access Longhorn UI"
  value       = var.ingress_enabled ? "https://${var.ingress_host}" : null
}

output "storage_class_name" {
  description = "Name of the default Longhorn storage class"
  value       = "longhorn"
}

output "service_account_name" {
  description = "Name of the Longhorn service account"
  value       = var.service_account
}

output "default_data_path" {
  description = "Default path for Longhorn data storage"
  value       = var.default_data_path
}

output "replica_count" {
  description = "Default replica count for Longhorn volumes"
  value       = var.replica_count
}
