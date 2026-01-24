locals {
  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }
}

module "namespace" {
  source = "../../base/namespace"

  for_each = local.clusters

  create = true
  name   = each.value.name
  labels = {
    "kubernetes.io/metadata.name" = each.value.name
  }
  needs_secrets = true
}

resource "kubernetes_secret" "proxmox_credentials" {
  for_each = var.create_proxmox_secret ? local.clusters : {}

  metadata {
    name      = var.credentials_ref_name
    namespace = each.value.name
  }

  data = {
    url    = var.proxmox_url
    secret = var.proxmox_secret
    token  = var.proxmox_token
  }

  type = "Opaque"

  depends_on = [module.namespace]
}

module "cluster_templates" {
  source = "../../base/values-template"

  for_each = local.clusters

  template_files = each.value.cluster_type == "kubeadm" ? [
    # Kubeadm cluster templates
    {
      path = "${path.module}/templates/kubeadm-cluster.yaml.tpl"
      vars = {
        cluster_name               = each.value.name
        namespace                  = each.value.name
        kubeadm_control_plane_name = "${each.value.name}-control-plane"
        proxmox_cluster_name       = each.value.name
        pod_cidr                   = each.value.pod_cidr
        service_cidr               = each.value.service_cidr
      }
    },
    {
      path = "${path.module}/templates/cp-proxmoxcluster.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        proxmox_cluster_name        = each.value.name
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
      path = "${path.module}/templates/kubeadm-control-plane.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        kubeadm_control_plane_name  = "${each.value.name}-control-plane"
        kubernetes_version          = each.value.kubernetes_version
        cp_replicas                 = each.value.cp_replicas
        control_plane_template_name = "${each.value.name}-control-plane-template"
        control_plane_endpoint_ip   = each.value.control_plane_endpoint_ip
        cni_manifest_url            = each.value.cni_manifest_url
        ssh_authorized_keys         = jsonencode(var.ssh_authorized_keys)
      }
    },
    {
      path = "${path.module}/templates/cp-proxmoxmachinetemplate.yaml.tpl"
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
      path = "${path.module}/templates/wk-proxmoxmachinetemplate.yaml.tpl"
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
      path = "${path.module}/templates/kubeadm-config-template.yaml.tpl"
      vars = {
        cluster_name               = each.value.name
        namespace                  = each.value.name
        worker_kubeadm_config_name = "${each.value.name}-worker-config"
        ssh_authorized_keys        = jsonencode(var.ssh_authorized_keys)
      }
    },
    {
      path = "${path.module}/templates/kubeadm-machinedeployment.yaml.tpl"
      vars = {
        cluster_name               = each.value.name
        namespace                  = each.value.name
        worker_deployment_name     = "${each.value.name}-workers"
        worker_kubeadm_config_name = "${each.value.name}-worker-config"
        worker_template_name       = "${each.value.name}-worker-template"
        wk_replicas                = each.value.wk_replicas
        kubernetes_version         = each.value.kubernetes_version
        autoscaler_enabled         = each.value.autoscaler_enabled
        autoscaler_min             = each.value.autoscaler_min
        autoscaler_max             = each.value.autoscaler_max
      }
    }
    ] : each.value.cluster_type == "k0s" ? [
    # K0s cluster templates
    {
      path = "${path.module}/templates/k0s-cluster.yaml.tpl"
      vars = {
        cluster_name                 = each.value.name
        namespace                    = each.value.name
        k0smotron_control_plane_name = "${each.value.name}-k0s-cp"
        proxmox_cluster_name         = each.value.name
        pod_cidr                     = each.value.pod_cidr
        service_cidr                 = each.value.service_cidr
      }
    },
    {
      path = "${path.module}/templates/k0s-ingress.yaml.tpl"
      vars = {
        cluster_name                 = each.value.name
        namespace                    = each.value.name
        control_plane_endpoint_host  = each.value.control_plane_endpoint_host
        k0smotron_control_plane_name = "${each.value.name}-k0s-cp"
      }
    },
    {
      path = "${path.module}/templates/cp-proxmoxcluster.yaml.tpl"
      vars = {
        cluster_name                = each.value.name
        namespace                   = each.value.name
        proxmox_cluster_name        = each.value.name
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
      path = "${path.module}/templates/k0s-control-plane.yaml.tpl"
      vars = {
        cluster_name                 = each.value.name
        namespace                    = each.value.name
        k0smotron_control_plane_name = "${each.value.name}-k0s-cp"
        kubernetes_version           = each.value.kubernetes_version
        cp_replicas                  = each.value.cp_replicas
        control_plane_endpoint_host  = each.value.control_plane_endpoint_host
        cni_type                     = each.value.cni_type
        pod_cidr                     = each.value.pod_cidr
        service_cidr                 = each.value.service_cidr
      }
    },
    {
      path = "${path.module}/templates/wk-proxmoxmachinetemplate.yaml.tpl"
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
      path = "${path.module}/templates/k0s-worker-config-template.yaml.tpl"
      vars = {
        cluster_name           = each.value.name
        namespace              = each.value.name
        worker_k0s_config_name = "${each.value.name}-worker-k0s-config"
        kubernetes_version     = each.value.kubernetes_version
      }
    },
    {
      path = "${path.module}/templates/k0s-machinedeployment.yaml.tpl"
      vars = {
        cluster_name           = each.value.name
        namespace              = each.value.name
        worker_deployment_name = "${each.value.name}-k0s-workers"
        worker_k0s_config_name = "${each.value.name}-worker-k0s-config"
        worker_template_name   = "${each.value.name}-worker-template"
        wk_replicas            = each.value.wk_replicas
        kubernetes_version     = each.value.kubernetes_version
        autoscaler_enabled     = each.value.autoscaler_enabled
        autoscaler_min         = each.value.autoscaler_min
        autoscaler_max         = each.value.autoscaler_max
      }
    }
    ] : [
    # Talos cluster templates (existing)
    {
      path = "${path.module}/templates/cp-cluster.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = each.value.name
        talos_control_plane_name = "${each.value.name}-talos-cp"
        proxmox_cluster_name     = "${each.value.name}-proxmox-cluster"
      }
    },
    {
      path = "${path.module}/templates/cp-proxmoxcluster.yaml.tpl"
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
      path = "${path.module}/templates/cp-taloscontrolplane.yaml.tpl"
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
      path = "${path.module}/templates/cp-proxmoxmachinetemplate.yaml.tpl"
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
      path = "${path.module}/templates/wk-proxmoxmachinetemplate.yaml.tpl"
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
      path = "${path.module}/templates/wk-talosconfigtemplate.yaml.tpl"
      vars = {
        cluster_name             = each.value.name
        namespace                = each.value.name
        worker_talos_config_name = "${each.value.name}-talosconfig-workers"
        install_disk             = each.value.install_disk
      }
    },
    {
      path = "${path.module}/templates/wk-machinedeployment.yaml.tpl"
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
  # Create a nested map: cluster_name => "kind-name" => manifest
  # This allows us to reference specific manifests by kind and name for explicit resource ordering
  cluster_manifests = {
    for cluster_name, cluster_config in local.clusters : cluster_name => {
      for template_content in module.cluster_templates[cluster_name].rendered_values :
      "${yamldecode(template_content).kind}-${yamldecode(template_content).metadata.name}" => yamldecode(template_content)
    }
  }
}

# Infrastructure Layer - Created first
resource "kubernetes_manifest" "proxmox_cluster" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["ProxmoxCluster-${(each.value.cluster_type == "kubeadm" || each.value.cluster_type == "k0s") ? each.value.name : "${each.value.name}-proxmox-cluster"}"]

  depends_on = [
    kubernetes_secret.proxmox_credentials,
    var.cluster_api_dependencies
  ]
}

resource "kubernetes_manifest" "control_plane_machine_template" {
  for_each = {
    for name, cluster in local.clusters : name => cluster
    if cluster.cluster_type != "k0s"
  }

  manifest = local.cluster_manifests[each.key]["ProxmoxMachineTemplate-${each.value.name}-control-plane-template"]

  depends_on = [module.namespace]
}

resource "kubernetes_manifest" "worker_machine_template" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["ProxmoxMachineTemplate-${each.value.name}-worker-template"]

  depends_on = [module.namespace]
}

# Bootstrap Layer - Created second
resource "kubernetes_manifest" "control_plane" {
  for_each = local.clusters

  # Different kinds based on cluster_type
  manifest = local.cluster_manifests[each.key][
    each.value.cluster_type == "kubeadm"
    ? "KubeadmControlPlane-${each.value.name}-control-plane"
    : each.value.cluster_type == "k0s"
    ? "K0smotronControlPlane-${each.value.name}-k0s-cp"
    : "TalosControlPlane-${each.value.name}-talos-cp"
  ]

  depends_on = [module.namespace]
}

resource "kubernetes_manifest" "worker_config_template" {
  for_each = local.clusters

  # Different kinds based on cluster_type
  manifest = local.cluster_manifests[each.key][
    each.value.cluster_type == "kubeadm"
    ? "KubeadmConfigTemplate-${each.value.name}-worker-config"
    : each.value.cluster_type == "k0s"
    ? "K0sWorkerConfigTemplate-${each.value.name}-worker-k0s-config"
    : "TalosConfigTemplate-${each.value.name}-talosconfig-workers"
  ]

  depends_on = [module.namespace]
}

resource "kubernetes_manifest" "machine_deployment" {
  for_each = local.clusters

  # Name differs between types
  manifest = local.cluster_manifests[each.key][
    each.value.cluster_type == "kubeadm"
    ? "MachineDeployment-${each.value.name}-workers"
    : each.value.cluster_type == "k0s"
    ? "MachineDeployment-${each.value.name}-k0s-workers"
    : "MachineDeployment-${each.value.name}-machinedeploy-workers"
  ]

  depends_on = [module.namespace]
}

# Cluster Layer - Created last, depends on everything
resource "kubernetes_manifest" "cluster" {
  for_each = local.clusters

  manifest = local.cluster_manifests[each.key]["Cluster-${each.value.name}"]

  dynamic "wait" {
    for_each = [1]
    content {
      condition {
        type   = "Available"
        status = "True"
      }
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    module.namespace,
    kubernetes_manifest.proxmox_cluster,
    kubernetes_manifest.control_plane,
    kubernetes_manifest.control_plane_machine_template,
    kubernetes_manifest.machine_deployment,
    kubernetes_manifest.worker_config_template,
    kubernetes_manifest.worker_machine_template,
    kubernetes_secret.proxmox_credentials
  ]
}

# Ingress for k0s control plane - only created for k0s clusters
resource "kubernetes_manifest" "control_plane_ingress" {
  for_each = {
    for name, cluster in local.clusters : name => cluster
    if cluster.cluster_type == "k0s"
  }

  manifest = local.cluster_manifests[each.key]["Ingress-${each.value.name}-apiserver"]

  depends_on = [
    module.namespace,
    kubernetes_manifest.control_plane
  ]
}
