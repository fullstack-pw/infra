output "clusters" {
  description = "Map of created Talos clusters"
  value = {
    for name, cluster in kubernetes_manifest.cluster : name => {
      name      = cluster.manifest.metadata.name
      namespace = cluster.manifest.metadata.namespace
    }
  }
}

output "cluster_names" {
  description = "List of created Talos cluster names"
  value       = [for name in keys(local.clusters) : name]
}
