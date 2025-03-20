output "namespace" {
  description = "Namespace where external-secrets is installed"
  value       = module.namespace.name
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = "vault-backend"
}

output "vault_path" {
  description = "Vault path for secrets"
  value       = var.vault_path
}

output "helm_release_name" {
  description = "Helm release name"
  value       = module.helm.name
}

output "vault_token_secret_name" {
  description = "Name of the Vault token secret"
  value       = module.vault_token_secret.name
}
