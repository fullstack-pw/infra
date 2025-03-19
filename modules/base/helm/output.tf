output "name" {
  description = "Name of the Helm release"
  value       = helm_release.this.name
}

output "namespace" {
  description = "Namespace where the Helm release is deployed"
  value       = helm_release.this.namespace
}

output "version" {
  description = "Version of the deployed chart"
  value       = var.chart_version
}

output "chart" {
  description = "Name of the deployed chart"
  value       = var.chart
}

output "status" {
  description = "Status of the release"
  value       = helm_release.this.status
}

output "metadata" {
  description = "Block status of the deployed release"
  value       = helm_release.this.metadata
}
