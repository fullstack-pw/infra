output "gitlab_runner_sa_name" {
  description = "GitLab Runner Service Account Name"
  value       = kubernetes_service_account.gitlab_runner.metadata[0].name
}

output "namespace" {
  description = "Namespace where GitLab Runner is deployed"
  value       = kubernetes_namespace.gitlab.metadata[0].name
}
