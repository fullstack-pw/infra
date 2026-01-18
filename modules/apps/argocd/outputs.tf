output "namespace" {
  description = "Namespace where Argo CD is installed"
  value       = module.namespace.name
}

output "argocd_url" {
  description = "Argo CD UI URL"
  value       = var.ingress_enabled ? "https://${var.argocd_domain}" : "Port-forward to service/argocd-server"
}

output "helm_release_name" {
  description = "Helm release name for Argo CD"
  value       = var.install_argocd ? module.helm[0].name : "not-installed"
}

output "helm_release_status" {
  description = "Helm release status"
  value       = var.install_argocd ? module.helm[0].status : "not-installed"
}
