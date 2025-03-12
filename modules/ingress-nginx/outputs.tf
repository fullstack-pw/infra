output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.nginx.name
}

output "namespace" {
  description = "Namespace of the deployed ingress controller"
  value       = helm_release.nginx.namespace
}

output "version" {
  description = "Version of the deployed ingress controller"
  value       = var.chart_version
}
