output "clusters" {
  description = "Map of created K3s clusters"
  value = {
    for name, cluster in kubernetes_manifest.cluster : name => {
      name      = cluster.manifest.metadata.name
      namespace = cluster.manifest.metadata.namespace
    }
  }
}

output "cluster_names" {
  description = "List of created K3s cluster names"
  value       = [for name in keys(local.clusters) : name]
}
