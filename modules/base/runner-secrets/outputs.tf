/**
 * Outputs for Runner Secrets module
 */

output "secret_name" {
  description = "Name of the Kubernetes secret containing the age key"
  value       = kubernetes_secret.age_key.metadata[0].name
}

output "secret_namespace" {
  description = "Namespace of the Kubernetes secret containing the age key"
  value       = kubernetes_secret.age_key.metadata[0].namespace
}

output "github_runner_secret_name" {
  description = "Name of the Kubernetes secret for GitHub runners"
  value       = var.create_github_runner_secret ? kubernetes_secret.github_runner_age_key[0].metadata[0].name : null
}

output "gitlab_runner_secret_name" {
  description = "Name of the Kubernetes secret for GitLab runners"
  value       = var.create_gitlab_runner_secret ? kubernetes_secret.gitlab_runner_age_key[0].metadata[0].name : null
}
