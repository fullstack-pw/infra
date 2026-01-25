output "proxmox_cluster_names" {
  description = "Names of the created clusters"
  value       = length(module.kubernetes_clusters) > 0 ? module.kubernetes_clusters[0].cluster_names : []
}

output "proxmox_cluster_endpoints" {
  description = "Control plane endpoints for each cluster"
  value       = length(module.kubernetes_clusters) > 0 ? module.kubernetes_clusters[0].cluster_endpoints : {}
}

output "proxmox_cluster_configurations" {
  description = "Full cluster configurations"
  value       = length(module.kubernetes_clusters) > 0 ? module.kubernetes_clusters[0].cluster_configurations : {}
}

output "proxmox_applied_manifests" {
  description = "List of applied manifest types and names"
  value       = length(module.kubernetes_clusters) > 0 ? module.kubernetes_clusters[0].applied_manifests : []
}

output "proxmox_manifest_count" {
  description = "Number of manifests created"
  value       = length(module.kubernetes_clusters) > 0 ? module.kubernetes_clusters[0].manifest_count : 0
}
