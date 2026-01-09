output "namespace" {
  description = "Namespace where cluster-autoscaler is deployed"
  value       = module.namespace.name
}

output "release_name" {
  description = "Helm release name"
  value       = "cluster-autoscaler"
}

output "service_account" {
  description = "ServiceAccount name"
  value       = "cluster-autoscaler"
}
