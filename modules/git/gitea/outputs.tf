output "namespace" {
  description = "Namespace where Gitea is deployed"
  value       = module.namespace.name
}

output "release_name" {
  description = "Name of the Gitea Helm release"
  value       = module.helm.name
}

output "url" {
  description = "Gitea URL"
  value       = "https://${var.domain}"
}

output "ssh_url" {
  description = "Gitea SSH URL"
  value       = "ssh://git@${var.ssh_domain}:${var.ssh_port}"
}
