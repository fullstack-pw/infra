locals {
  clusters_by_type = {
    for cluster_type in distinct([for c in var.clusters : lookup(c, "cluster_type", "talos")]) :
    cluster_type => [
      for c in var.clusters :
      c if lookup(c, "cluster_type", "talos") == cluster_type
    ]
  }
}

module "core" {
  source = "./core"

  clusters = var.clusters

  create_proxmox_secret = var.create_proxmox_secret
  credentials_ref_name  = var.credentials_ref_name
  proxmox_url           = var.proxmox_url
  proxmox_secret        = var.proxmox_secret
  proxmox_token         = var.proxmox_token

  cluster_api_dependencies = var.cluster_api_dependencies
}

module "talos_clusters" {
  count  = contains(keys(local.clusters_by_type), "talos") ? 1 : 0
  source = "./talos"

  clusters = local.clusters_by_type["talos"]

  credentials_ref_name = var.credentials_ref_name

  qemu_guest_agent_image     = var.qemu_guest_agent_image
  cloud_controller_manifests = var.cloud_controller_manifests

  core_module_namespaces = module.core.namespaces

  depends_on = [module.core]
}

module "kubeadm_clusters" {
  count  = contains(keys(local.clusters_by_type), "kubeadm") ? 1 : 0
  source = "./kubeadm"

  clusters = local.clusters_by_type["kubeadm"]

  credentials_ref_name = var.credentials_ref_name
  ssh_authorized_keys  = var.ssh_authorized_keys

  core_module_namespaces = module.core.namespaces

  depends_on = [module.core]
}

module "k3s_clusters" {
  count  = contains(keys(local.clusters_by_type), "k3s") ? 1 : 0
  source = "./k3s"

  clusters = local.clusters_by_type["k3s"]

  credentials_ref_name = var.credentials_ref_name
  ssh_authorized_keys  = var.ssh_authorized_keys

  core_module_namespaces = module.core.namespaces

  depends_on = [module.core]
}

module "k0s_clusters" {
  count  = contains(keys(local.clusters_by_type), "k0s") ? 1 : 0
  source = "./k0s"

  clusters = local.clusters_by_type["k0s"]

  credentials_ref_name = var.credentials_ref_name
  ssh_authorized_keys  = var.ssh_authorized_keys

  core_module_namespaces = module.core.namespaces

  depends_on = [module.core]
}

module "rke2_clusters" {
  count  = contains(keys(local.clusters_by_type), "rke2") ? 1 : 0
  source = "./rke2"

  clusters = local.clusters_by_type["rke2"]

  credentials_ref_name = var.credentials_ref_name
  ssh_authorized_keys  = var.ssh_authorized_keys

  core_module_namespaces = module.core.namespaces

  depends_on = [module.core]
}
