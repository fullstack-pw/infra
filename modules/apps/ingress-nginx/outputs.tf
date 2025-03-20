output "release_name" {
  description = "Name of the Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace of the deployed ingress controller"
  value       = module.helm.namespace
}

output "version" {
  description = "Version of the deployed ingress controller"
  value       = var.chart_version
}
