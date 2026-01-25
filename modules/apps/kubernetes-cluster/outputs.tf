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

locals {
  all_manifests = merge(
    length(module.talos_clusters) > 0 ? {
      for name in module.talos_clusters[0].cluster_names :
      name => {
        cluster                        = 1
        proxmox_cluster                = 1
        control_plane                  = 1
        control_plane_machine_template = 1
        worker_machine_template        = 1
        worker_config_template         = 1
        machine_deployment             = 1
      }
    } : {},
    length(module.kubeadm_clusters) > 0 ? {
      for name in module.kubeadm_clusters[0].cluster_names :
      name => {
        cluster                        = 1
        proxmox_cluster                = 1
        control_plane                  = 1
        control_plane_machine_template = 1
        worker_machine_template        = 1
        worker_config_template         = 1
        machine_deployment             = 1
      }
    } : {},
    length(module.k3s_clusters) > 0 ? {
      for name in module.k3s_clusters[0].cluster_names :
      name => {
        cluster                        = 1
        proxmox_cluster                = 1
        control_plane                  = 1
        control_plane_machine_template = 1
        worker_machine_template        = 1
        worker_config_template         = 1
        machine_deployment             = 1
      }
    } : {},
    length(module.k0s_clusters) > 0 ? {
      for name in module.k0s_clusters[0].cluster_names :
      name => {
        cluster                        = 1
        proxmox_cluster                = 1
        control_plane                  = 1
        control_plane_machine_template = 1
        worker_machine_template        = 1
        worker_config_template         = 1
        machine_deployment             = 1
      }
    } : {},
    length(module.rke2_clusters) > 0 ? {
      for name in module.rke2_clusters[0].cluster_names :
      name => {
        cluster                        = 1
        proxmox_cluster                = 1
        control_plane                  = 1
        control_plane_machine_template = 1
        worker_machine_template        = 1
        worker_config_template         = 1
        machine_deployment             = 1
      }
    } : {}
  )
}

output "manifest_count" {
  description = "Number of manifests created"
  value = sum([
    for cluster_manifests in values(local.all_manifests) :
    sum(values(cluster_manifests))
  ])
}

output "applied_manifests" {
  description = "List of applied manifest types and names"
  value = concat(
    length(module.talos_clusters) > 0 ? flatten([
      for name in module.talos_clusters[0].cluster_names : [
        { kind = "Cluster", name = name, namespace = name },
        { kind = "ProxmoxCluster", name = name, namespace = name },
        { kind = "TalosControlPlane", name = "${name}-talos-cp", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-control-plane-template", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-worker-template", namespace = name },
        { kind = "TalosConfigTemplate", name = "${name}-talosconfig-workers", namespace = name },
        { kind = "MachineDeployment", name = "${name}-machinedeploy-workers", namespace = name }
      ]
    ]) : [],
    length(module.kubeadm_clusters) > 0 ? flatten([
      for name in module.kubeadm_clusters[0].cluster_names : [
        { kind = "Cluster", name = name, namespace = name },
        { kind = "ProxmoxCluster", name = name, namespace = name },
        { kind = "KubeadmControlPlane", name = "${name}-control-plane", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-control-plane-template", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-worker-template", namespace = name },
        { kind = "KubeadmConfigTemplate", name = "${name}-worker-config", namespace = name },
        { kind = "MachineDeployment", name = "${name}-workers", namespace = name }
      ]
    ]) : [],
    length(module.k3s_clusters) > 0 ? flatten([
      for name in module.k3s_clusters[0].cluster_names : [
        { kind = "Cluster", name = name, namespace = name },
        { kind = "ProxmoxCluster", name = name, namespace = name },
        { kind = "KThreesControlPlane", name = "${name}-k3s-cp", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-control-plane-template", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-worker-template", namespace = name },
        { kind = "KThreesConfigTemplate", name = "${name}-worker-config", namespace = name },
        { kind = "MachineDeployment", name = "${name}-workers", namespace = name }
      ]
    ]) : [],
    length(module.k0s_clusters) > 0 ? flatten([
      for name in module.k0s_clusters[0].cluster_names : [
        { kind = "Cluster", name = name, namespace = name },
        { kind = "ProxmoxCluster", name = name, namespace = name },
        { kind = "K0sControlPlane", name = "${name}-k0s-cp", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-control-plane-template", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-worker-template", namespace = name },
        { kind = "K0sWorkerConfigTemplate", name = "${name}-worker-config", namespace = name },
        { kind = "MachineDeployment", name = "${name}-workers", namespace = name }
      ]
    ]) : [],
    length(module.rke2_clusters) > 0 ? flatten([
      for name in module.rke2_clusters[0].cluster_names : [
        { kind = "Cluster", name = name, namespace = name },
        { kind = "ProxmoxCluster", name = name, namespace = name },
        { kind = "RKE2ControlPlane", name = "${name}-rke2-cp", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-control-plane-template", namespace = name },
        { kind = "ProxmoxMachineTemplate", name = "${name}-worker-template", namespace = name },
        { kind = "RKE2ConfigTemplate", name = "${name}-worker-config", namespace = name },
        { kind = "MachineDeployment", name = "${name}-workers", namespace = name }
      ]
    ]) : []
  )
}

output "core_namespaces" {
  description = "Namespaces created by the core module"
  value       = module.core.namespaces
}

output "talos_clusters" {
  description = "Talos clusters created"
  value       = length(module.talos_clusters) > 0 ? module.talos_clusters[0].clusters : {}
}

output "kubeadm_clusters" {
  description = "Kubeadm clusters created"
  value       = length(module.kubeadm_clusters) > 0 ? module.kubeadm_clusters[0].clusters : {}
}

output "k3s_clusters" {
  description = "K3s clusters created"
  value       = length(module.k3s_clusters) > 0 ? module.k3s_clusters[0].clusters : {}
}

output "k0s_clusters" {
  description = "K0s clusters created"
  value       = length(module.k0s_clusters) > 0 ? module.k0s_clusters[0].clusters : {}
}

output "rke2_clusters" {
  description = "RKE2 clusters created"
  value       = length(module.rke2_clusters) > 0 ? module.rke2_clusters[0].clusters : {}
}

output "all_clusters" {
  description = "All clusters created across all types"
  value = merge(
    length(module.talos_clusters) > 0 ? module.talos_clusters[0].clusters : {},
    length(module.kubeadm_clusters) > 0 ? module.kubeadm_clusters[0].clusters : {},
    length(module.k3s_clusters) > 0 ? module.k3s_clusters[0].clusters : {},
    length(module.k0s_clusters) > 0 ? module.k0s_clusters[0].clusters : {},
    length(module.rke2_clusters) > 0 ? module.rke2_clusters[0].clusters : {}
  )
}
