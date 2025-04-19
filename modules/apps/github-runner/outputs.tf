output "namespace" {
  description = "Namespace where GitHub runners are deployed"
  value       = module.namespace.name
}

output "service_account_name" {
  description = "Service account name for GitHub runners"
  value       = kubernetes_service_account.github_runner.metadata[0].name
}

output "controller_release_name" {
  description = "Name of the GitHub Actions Runner Controller Helm release"
  value       = module.controller_helm.name
}

output "runner_release_name" {
  description = "Name of the GitHub Runner Scale Set Helm release"
  value       = module.runner_helm.name
}

output "min_runners" {
  description = "Minimum number of GitHub runners"
  value       = var.min_runners
}

output "max_runners" {
  description = "Maximum number of GitHub runners"
  value       = var.max_runners
}
