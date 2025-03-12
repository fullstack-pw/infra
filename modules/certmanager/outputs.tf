output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "cluster_issuer" {
  description = "Name of the ClusterIssuer"
  value       = var.cluster_issuer
}
