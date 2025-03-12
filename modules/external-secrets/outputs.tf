output "external_secrets_namespace" {
  description = "Namespace where external-secrets is installed"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = "vault-backend"
}
