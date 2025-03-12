output "namespace" {
  description = "Namespace where GitHub runners are deployed"
  value       = kubernetes_namespace.arc_namespace.metadata[0].name
}

output "service_account_name" {
  description = "Service account name for GitHub runners"
  value       = kubernetes_service_account.github_runner.metadata[0].name
}

output "controller_release_name" {
  description = "Name of the GitHub Actions Runner Controller Helm release"
  value       = helm_release.arc.name
}

output "runner_deployment_name" {
  description = "Name of the GitHub runner deployment"
  value       = "github-runner"
}

output "autoscaler_enabled" {
  description = "Whether autoscaling is enabled for GitHub runners"
  value       = var.enable_autoscaling
}

output "autoscaler_name" {
  description = "Name of the GitHub runner autoscaler (if enabled)"
  value       = var.enable_autoscaling ? "github-runner-autoscaler" : null
}
