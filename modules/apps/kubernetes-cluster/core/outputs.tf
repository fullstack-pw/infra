output "namespaces" {
  description = "Map of created namespaces"
  value       = { for k, v in module.namespace : k => v }
}

output "credentials_secrets" {
  description = "Map of created Proxmox credentials secrets"
  value       = { for k, v in kubernetes_secret.proxmox_credentials : k => v.metadata[0].name }
}
