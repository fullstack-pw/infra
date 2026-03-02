output "release_name" {
  description = "Name of the gitea-runner Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace where the runner is deployed"
  value       = var.namespace
}
