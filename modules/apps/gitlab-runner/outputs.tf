output "namespace" {
  description = "Namespace where GitLab Runner is deployed"
  value       = module.namespace.name
}

output "service_account_name" {
  description = "GitLab Runner Service Account Name"
  value       = kubernetes_service_account.gitlab_runner.metadata[0].name
}

output "release_name" {
  description = "Name of the GitLab Runner Helm release"
  value       = module.helm.name
}

output "concurrent_runners" {
  description = "Number of concurrent runners configured"
  value       = var.concurrent_runners
}
