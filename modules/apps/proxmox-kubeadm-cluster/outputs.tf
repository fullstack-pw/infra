output "cluster_names" {
  description = "Names of created Kubeadm clusters"
  value       = [for cluster in var.clusters : cluster.name]
}

output "namespaces" {
  description = "Map of cluster names to their namespaces"
  value       = { for name, ns in module.namespace : name => ns.name }
}
