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
  value       = module.helm.name
}

output "runner_deployment_name" {
  description = "Name of the GitHub runner deployment"
  value       = var.runner_name
}

output "autoscaler_enabled" {
  description = "Whether autoscaling is enabled for GitHub runners"
  value       = var.enable_autoscaling
}

output "autoscaler_name" {
  description = "Name of the GitHub runner autoscaler (if enabled)"
  value       = var.enable_autoscaling ? "${var.runner_name}-autoscaler" : null
}
