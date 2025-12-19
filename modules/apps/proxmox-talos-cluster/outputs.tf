output "cluster_names" {
  description = "Names of the created clusters"
  value       = [for cluster in var.clusters : cluster.name]
}

output "cluster_endpoints" {
  description = "Control plane endpoints for each cluster"
  value = {
    for cluster in var.clusters : cluster.name => {
      ip   = cluster.control_plane_endpoint_ip
      port = cluster.control_plane_endpoint_port
      url  = "https://${cluster.control_plane_endpoint_ip}:${cluster.control_plane_endpoint_port}"
    }
  }
}

output "cluster_configurations" {
  description = "Full cluster configurations"
  value = {
    for cluster in var.clusters : cluster.name => {
      kubernetes_version     = cluster.kubernetes_version
      cp_replicas            = cluster.cp_replicas
      wk_replicas            = cluster.wk_replicas
      control_plane_endpoint = "${cluster.control_plane_endpoint_ip}:${cluster.control_plane_endpoint_port}"
      ip_range               = "${cluster.ip_range_start}-${cluster.ip_range_end}"
      gateway                = cluster.gateway
      source_node            = cluster.source_node
      template_id            = cluster.template_id
    }
  }
}

output "manifest_count" {
  description = "Number of manifests created"
  value       = length(local.all_manifests)
}

output "applied_manifests" {
  description = "List of applied manifest types and names"
  value = [
    for manifest in local.all_manifests : {
      kind      = manifest.kind
      name      = manifest.metadata.name
      namespace = manifest.metadata.namespace
    }
  ]
}
