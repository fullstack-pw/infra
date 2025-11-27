output "cluster_names" {
  description = "Names of created Kubeadm clusters"
  value       = [for cluster in var.clusters : cluster.name]
}

output "namespace" {
  description = "Namespace where cluster resources are created"
  value       = module.namespace.name
}
