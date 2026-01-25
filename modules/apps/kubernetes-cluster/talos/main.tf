locals {
  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }
}

module "cluster_templates" {
  source = "../../../base/values-template"

  for_each = local.clusters

  template_files = [
    {
      path = "${path.module}/templates/cluster.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = each.value.name
        talos_control_plane_name = "${each.value.name}-talos-cp"
        proxmox_cluster_name     = "${each.value.name}-proxmox-cluster"
      }
    },
    {
      path = "${path.module}/../core/templates/proxmoxcluster.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        proxmox_cluster_name        = "${each.value.name}-proxmox-cluster"
        control_plane_endpoint_ip   = each.value.control_plane_endpoint_ip
        control_plane_endpoint_port = each.value.control_plane_endpoint_port
        dns_servers                 = jsonencode(each.value.dns_servers)
        ip_range_start              = each.value.ip_range_start
        ip_range_end                = each.value.ip_range_end
        gateway                     = each.value.gateway
        prefix                      = each.value.prefix
        allowed_nodes               = jsonencode(each.value.allowed_nodes)
        credentials_ref_name        = var.credentials_ref_name
        memory_adjustment           = each.value.memory_adjustment
      }
    },
    {
      path = "${path.module}/templates/controlplane.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        talos_control_plane_name    = "${each.value.name}-talos-cp"
        kubernetes_version          = each.value.kubernetes_version
        cp_replicas                 = each.value.cp_replicas
        control_plane_template_name = "${each.value.name}-control-plane-template"
        control_plane_endpoint_ip   = each.value.control_plane_endpoint_ip
        install_disk                = each.value.install_disk
        qemu_guest_agent_image      = var.qemu_guest_agent_image
        cloud_controller_manifests  = jsonencode(var.cloud_controller_manifests)
      }
    },
    {
      path = "${path.module}/../core/templates/cp-proxmoxmachinetemplate.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        control_plane_template_name = "${each.value.name}-control-plane-template"
        cp_disk_size                = each.value.cp_disk_size
        cp_memory                   = each.value.cp_memory
        cp_cores                    = each.value.cp_cores
        cp_sockets                  = each.value.cp_sockets
        source_node                 = each.value.source_node
        template_id                 = each.value.template_id
        network_bridge              = each.value.network_bridge
        network_model               = each.value.network_model
        disk_format                 = each.value.disk_format
        skip_cloud_init_status      = each.value.skip_cloud_init_status
        skip_qemu_guest_agent       = each.value.skip_qemu_guest_agent
        provider_id_injection       = each.value.provider_id_injection
      }
    },
    {
      path = "${path.module}/../core/templates/wk-proxmoxmachinetemplate.yaml.tpl"
      vars = {
        cluster_name           = each.value.name
        namespace              = each.value.name
        worker_template_name   = "${each.value.name}-worker-template"
        wk_disk_size           = each.value.wk_disk_size
        wk_memory              = each.value.wk_memory
        wk_cores               = each.value.wk_cores
        wk_sockets             = each.value.wk_sockets
        source_node            = each.value.source_node
        template_id            = each.value.template_id
        network_bridge         = each.value.network_bridge
        network_model          = each.value.network_model
        disk_format            = each.value.disk_format
        skip_cloud_init_status = each.value.skip_cloud_init_status
        skip_qemu_guest_agent  = each.value.skip_qemu_guest_agent
        provider_id_injection  = each.value.provider_id_injection
      }
    },
    {
      path = "${path.module}/templates/worker-config.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = each.value.name
        worker_talos_config_name = "${each.value.name}-talosconfig-workers"
        install_disk             = each.value.install_disk
      }
    },
    {
      path = "${path.module}/templates/machinedeployment.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = each.value.name
        worker_deployment_name   = "${each.value.name}-machinedeploy-workers"
        worker_talos_config_name = "${each.value.name}-talosconfig-workers"
        worker_template_name     = "${each.value.name}-worker-template"
        wk_replicas              = each.value.wk_replicas
        kubernetes_version       = each.value.kubernetes_version
        autoscaler_enabled       = each.value.autoscaler_enabled
        autoscaler_min           = each.value.autoscaler_min
        autoscaler_max           = each.value.autoscaler_max
      }
    }
  ]
}

locals {
  cluster_manifests = {
    for cluster_name, cluster_config in local.clusters : cluster_name => {
      for template_content in module.cluster_templates[cluster_name].rendered_values :
      "${yamldecode(template_content).kind}-${yamldecode(template_content).metadata.name}" => yamldecode(template_content)
    }
  }
}

resource "kubernetes_manifest" "proxmox_cluster" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["ProxmoxCluster-${each.value.name}-proxmox-cluster"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "control_plane_machine_template" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["ProxmoxMachineTemplate-${each.value.name}-control-plane-template"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "worker_machine_template" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["ProxmoxMachineTemplate-${each.value.name}-worker-template"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "control_plane" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["TalosControlPlane-${each.value.name}-talos-cp"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "worker_config_template" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["TalosConfigTemplate-${each.value.name}-talosconfig-workers"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "machine_deployment" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["MachineDeployment-${each.value.name}-machinedeploy-workers"]

  depends_on = [var.core_module_namespaces]
}

resource "kubernetes_manifest" "cluster" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["Cluster-${each.value.name}"]

  depends_on = [
    var.core_module_namespaces,
    kubernetes_manifest.proxmox_cluster,
    kubernetes_manifest.control_plane,
    kubernetes_manifest.control_plane_machine_template,
    kubernetes_manifest.machine_deployment,
    kubernetes_manifest.worker_config_template,
    kubernetes_manifest.worker_machine_template
  ]
}
