output "namespace" {
  description = "The namespace where Vault is deployed"
  value       = local.namespace
}

output "release_name" {
  description = "The name of the Vault Helm release"
  value       = helm_release.vault.name
}

output "vault_service_name" {
  description = "The name of the Vault service"
  value       = var.release_name
}

output "vault_internal_endpoint" {
  description = "The internal endpoint for Vault (cluster-local)"
  value       = "http://${var.release_name}.${local.namespace}.svc.cluster.local:8200"
}

output "vault_external_endpoint" {
  description = "The external endpoint for Vault"
  value       = "https://${var.ingress_host}"
}

output "kv_path" {
  description = "The path of the KV secrets engine"
  value       = var.initialize_vault ? vault_mount.kv[0].path : var.kv_path
}

output "kubernetes_auth_path" {
  description = "The path of the Kubernetes auth method"
  value       = var.initialize_vault ? vault_auth_backend.kubernetes[0].path : "kubernetes"
}

output "created_policies" {
  description = "List of policies created in Vault"
  value       = var.initialize_vault ? [for policy in vault_policy.policies : policy.name] : []
}
