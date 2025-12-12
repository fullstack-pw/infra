# Expose proxmox-talos-cluster module outputs
output "proxmox_talos_cluster_names" {
  description = "Names of the created Talos clusters"
  value       = length(module.proxmox_talos_clusters) > 0 ? module.proxmox_talos_clusters[0].cluster_names : []
}

output "proxmox_talos_cluster_endpoints" {
  description = "Control plane endpoints for each Talos cluster"
  value       = length(module.proxmox_talos_clusters) > 0 ? module.proxmox_talos_clusters[0].cluster_endpoints : {}
}

output "proxmox_talos_cluster_configurations" {
  description = "Full cluster configurations"
  value       = length(module.proxmox_talos_clusters) > 0 ? module.proxmox_talos_clusters[0].cluster_configurations : {}
}

output "proxmox_talos_applied_manifests" {
  description = "List of applied manifest types and names"
  value       = length(module.proxmox_talos_clusters) > 0 ? module.proxmox_talos_clusters[0].applied_manifests : []
}

output "proxmox_talos_manifest_count" {
  description = "Number of manifests created"
  value       = length(module.proxmox_talos_clusters) > 0 ? module.proxmox_talos_clusters[0].manifest_count : 0
}
