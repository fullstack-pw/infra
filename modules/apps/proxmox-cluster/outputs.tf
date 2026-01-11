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
  value = sum([
    length(kubernetes_manifest.cluster),
    length(kubernetes_manifest.proxmox_cluster),
    length(kubernetes_manifest.control_plane),
    length(kubernetes_manifest.control_plane_machine_template),
    length(kubernetes_manifest.worker_machine_template),
    length(kubernetes_manifest.worker_config_template),
    length(kubernetes_manifest.machine_deployment)
  ])
}

output "applied_manifests" {
  description = "List of applied manifest types and names"
  value = concat(
    [for k, v in kubernetes_manifest.cluster : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.proxmox_cluster : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.control_plane : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.control_plane_machine_template : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.worker_machine_template : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.worker_config_template : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }],
    [for k, v in kubernetes_manifest.machine_deployment : {
      kind      = v.manifest.kind
      name      = v.manifest.metadata.name
      namespace = v.manifest.metadata.namespace
    }]
  )
}
