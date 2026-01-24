module "namespace" {
  source        = "../../base/namespace"
  create        = true
  name          = var.namespace
  needs_secrets = true
}

# Create Proxmox credentials secret
resource "kubernetes_secret" "proxmox_credentials" {
  count = var.enable_proxmox_provider ? 1 : 0

  metadata {
    name      = var.proxmox_secret_name
    namespace = module.namespace.name
  }

  data = {
    url    = base64encode(var.proxmox_url)
    secret = base64encode(var.proxmox_secret)
    token  = base64encode(var.proxmox_token)
  }

  type = "Opaque"

  depends_on = [module.namespace]
}

module "helm_release" {
  source = "../../base/helm"

  release_name     = "capi-operator"
  namespace        = module.namespace.name
  chart            = "cluster-api-operator"
  repository       = "https://kubernetes-sigs.github.io/cluster-api-operator"
  chart_version    = var.operator_version
  timeout          = 600
  create_namespace = false

  values_files = [templatefile("${path.module}/templates/values.yaml.tpl", {
    # Provider enablement flags
    enable_core_provider      = var.enable_core_provider
    enable_proxmox_provider   = var.enable_proxmox_provider
    enable_talos_provider     = var.enable_talos_provider
    enable_k3s_provider       = var.enable_k3s_provider
    enable_kubeadm_provider   = var.enable_kubeadm_provider
    enable_k0smotron_provider = var.enable_k0smotron_provider
    enable_ipam_provider      = var.enable_ipam_provider

    # Provider versions
    core_provider_version          = var.core_provider_version
    proxmox_provider_version       = var.proxmox_provider_version
    talos_bootstrap_version        = var.talos_bootstrap_version
    talos_controlplane_version     = var.talos_controlplane_version
    k3s_bootstrap_version          = var.k3s_bootstrap_version
    k3s_controlplane_version       = var.k3s_controlplane_version
    kubeadm_bootstrap_version      = var.kubeadm_bootstrap_version
    kubeadm_controlplane_version   = var.kubeadm_controlplane_version
    k0smotron_bootstrap_version    = var.k0smotron_bootstrap_version
    k0smotron_controlplane_version = var.k0smotron_controlplane_version
    ipam_version                   = var.ipam_version

    # Proxmox configuration
    proxmox_secret_name = var.proxmox_secret_name
    namespace           = module.namespace.name
  })]

  depends_on = [
    module.namespace,
    kubernetes_secret.proxmox_credentials
  ]
}
