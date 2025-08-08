# modules/apps/proxmox-talos-cluster/main.tf

locals {
  # Flatten the clusters configuration for for_each
  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }
}

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

# Create Proxmox credentials secret (only once per namespace)
resource "kubernetes_secret" "proxmox_credentials" {
  count = var.create_proxmox_secret ? 1 : 0

  metadata {
    name      = var.credentials_ref_name
    namespace = var.namespace
  }

  data = {
    url    = var.proxmox_url
    secret = var.proxmox_secret
    token  = var.proxmox_token
  }

  type = "Opaque"
}

# Template rendering for cluster manifests
module "cluster_templates" {
  source = "../../base/values-template"

  for_each = local.clusters

  template_files = [
    # Main Cluster resource
    {
      path = "${path.module}/templates/cp-cluster.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = var.namespace
        talos_control_plane_name = "${each.value.name}-talos-cp"
        proxmox_cluster_name     = "${each.value.name}-proxmox-cluster"
      }
    },
    # ProxmoxCluster infrastructure
    {
      path = "${path.module}/templates/cp-proxmoxcluster.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = var.namespace
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
    # TalosControlPlane
    {
      path = "${path.module}/templates/cp-taloscontrolplane.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = var.namespace
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
    # Control Plane ProxmoxMachineTemplate
    {
      path = "${path.module}/templates/cp-proxmoxmachinetemplate.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = var.namespace
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
    # Worker ProxmoxMachineTemplate
    {
      path = "${path.module}/templates/wk-proxmoxmachinetemplate.yaml.tpl"
      vars = {
        cluster_name           = each.value.name
        namespace              = var.namespace
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
    # Worker TalosConfigTemplate
    {
      path = "${path.module}/templates/wk-talosconfigtemplate.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = var.namespace
        worker_talos_config_name = "${each.value.name}-talosconfig-workers"
        install_disk             = each.value.install_disk
      }
    },
    # Worker MachineDeployment
    {
      path = "${path.module}/templates/wk-machinedeployment.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = var.namespace
        worker_deployment_name   = "${each.value.name}-machinedeploy-workers"
        worker_talos_config_name = "${each.value.name}-talosconfig-workers"
        worker_template_name     = "${each.value.name}-worker-template"
        wk_replicas              = each.value.wk_replicas
        kubernetes_version       = each.value.kubernetes_version
      }
    }
  ]
}

# Parse the rendered YAML manifests and apply them
locals {
  # Parse all rendered manifests for each cluster
  all_manifests = flatten([
    for cluster_name, cluster_config in local.clusters : [
      for template_content in module.cluster_templates[cluster_name].rendered_values :
      yamldecode(template_content)
    ]
  ])

  # Create a map for kubernetes_manifest resources
  manifest_map = {
    for i, manifest in local.all_manifests :
    "${manifest.kind}-${manifest.metadata.name}-${manifest.metadata.namespace}" => manifest
  }
}

# Apply all cluster-api manifests
resource "kubernetes_manifest" "cluster_api_manifests" {
  for_each = local.manifest_map

  manifest = each.value

  wait {
    condition {
      type   = "Ready"
      status = "True"
    }
  }

  depends_on = [
    var.cluster_api_dependencies,
    kubernetes_secret.proxmox_credentials,
  ]
}
