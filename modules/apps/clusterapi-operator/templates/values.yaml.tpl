# Core Cluster API Provider
%{ if enable_core_provider ~}
core:
  cluster-api:
    version: "${core_provider_version}"
%{ endif ~}

# Infrastructure Providers
infrastructure:
%{ if enable_proxmox_provider ~}
  proxmox:
    enabled: yes
    version: "${proxmox_provider_version}"
    configSecret:
      name: "${proxmox_secret_name}"
      namespace: "${namespace}"
    fetchConfig:
      url: "https://github.com/ionos-cloud/cluster-api-provider-proxmox/releases/latest/infrastructure-components.yaml"
%{ endif ~}

# Bootstrap Providers
bootstrap:
%{ if enable_kubeadm_provider ~}
  kubeadm:
    version: "${kubeadm_bootstrap_version}"
%{ endif ~}
%{ if enable_talos_provider ~}
  talos:
    version: "${talos_bootstrap_version}"
%{ endif ~}
%{ if enable_k3s_provider ~}
  k3s:
    version: "${k3s_bootstrap_version}"
%{ endif ~}
%{ if enable_k0smotron_provider ~}
  k0sproject-k0smotron:
    version: "${k0smotron_bootstrap_version}"
%{ endif ~}

# ControlPlane Providers
controlPlane:
%{ if enable_kubeadm_provider ~}
  kubeadm:
    version: "${kubeadm_controlplane_version}"
%{ endif ~}
%{ if enable_talos_provider ~}
  talos:
    version: "${talos_controlplane_version}"
%{ endif ~}
%{ if enable_k3s_provider ~}
  k3s:
    version: "${k3s_controlplane_version}"
%{ endif ~}
%{ if enable_k0smotron_provider ~}
  k0sproject-k0smotron:
    version: "${k0smotron_controlplane_version}"
%{ endif ~}

# IPAM Providers
%{ if enable_ipam_provider ~}
ipam:
  in-cluster:
    version: "${ipam_version}"
%{ endif ~}
