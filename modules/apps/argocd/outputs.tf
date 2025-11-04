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
  value       = module.helm.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = module.helm.status
}
