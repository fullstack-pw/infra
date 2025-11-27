output "namespace" {
  description = "Namespace where operator is installed"
  value       = module.namespace.name
}

output "operator_version" {
  description = "Installed operator version"
  value       = var.operator_version
}

output "enabled_providers" {
  description = "List of enabled providers"
  value = {
    core    = var.enable_core_provider
    proxmox = var.enable_proxmox_provider
    talos   = var.enable_talos_provider
    k3s     = var.enable_k3s_provider
    kubeadm = var.enable_kubeadm_provider
    ipam    = var.enable_ipam_provider
  }
}

output "helm_release_status" {
  description = "Status of the Helm release - use this for dependencies"
  value       = module.helm_release
}
