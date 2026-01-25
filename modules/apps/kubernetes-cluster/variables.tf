variable "clusters" {
  description = "List of Talos, Kubeadm, K3s, K0s, or RKE2 clusters to create"
  type = list(object({
    cluster_type       = optional(string, "talos")
    name               = string
    kubernetes_version = optional(string, "v1.33.0")

    cp_replicas                 = optional(number, 3)
    control_plane_endpoint_ip   = string
    control_plane_endpoint_host = optional(string, "")
    control_plane_endpoint_port = optional(number, 6443)

    wk_replicas = optional(number, 3)

    autoscaler_enabled = optional(bool, false)
    autoscaler_min     = optional(number, 1)
    autoscaler_max     = optional(number, 10)

    ip_range_start = string
    ip_range_end   = string
    gateway        = string
    prefix         = number
    dns_servers    = optional(list(string), ["192.168.1.3", "8.8.4.4"])

    source_node       = string
    template_id       = number
    allowed_nodes     = optional(list(string), [])
    memory_adjustment = optional(number, 0)

    cp_disk_size = optional(number, 20)
    cp_memory    = optional(number, 2048)
    cp_cores     = optional(number, 2)
    cp_sockets   = optional(number, 1)

    wk_disk_size = optional(number, 20)
    wk_memory    = optional(number, 2048)
    wk_cores     = optional(number, 2)
    wk_sockets   = optional(number, 1)

    network_bridge = optional(string, "vmbr0")
    network_model  = optional(string, "virtio")

    disk_format  = optional(string, "qcow2")
    install_disk = optional(string, "/dev/sda")

    skip_cloud_init_status = optional(bool, true)
    skip_qemu_guest_agent  = optional(bool, true)
    provider_id_injection  = optional(bool, true)

    # Kubeadm-specific fields
    cni_type         = optional(string, "cilium")
    cni_manifest_url = optional(string, "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml")
    pod_cidr         = optional(string, "10.244.0.0/16")
    service_cidr     = optional(string, "10.96.0.0/12")

    # K3s-specific fields
    k3s_version              = optional(string, "v1.30.6+k3s1")
    disable_cloud_controller = optional(bool, false)
    disable_components       = optional(list(string), ["traefik", "servicelb"])
    node_labels              = optional(map(string), {})
    node_taints              = optional(list(string), [])

    # RKE2-specific fields
    rke2_version             = optional(string, "v1.33.1+rke2r1")
    rke2_cni                 = optional(string, "cilium")
    rke2_registration_method = optional(string, "internal-first")
    disable_rke2_components  = optional(list(string), [])
    rke2_server_args         = optional(list(string), [])
    rke2_agent_args          = optional(list(string), [])
    rke2_node_labels         = optional(map(string), {})
    rke2_node_taints         = optional(list(string), [])
  }))

  validation {
    condition     = length(var.clusters) > 0
    error_message = "At least one cluster must be defined."
  }

  validation {
    condition = alltrue([
      for cluster in var.clusters : can(regex("^[a-z0-9-]+$", cluster.name))
    ])
    error_message = "Cluster names must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition = alltrue([
      for cluster in var.clusters : contains(["talos", "kubeadm", "k3s", "k0s", "rke2"], lookup(cluster, "cluster_type", "talos"))
    ])
    error_message = "Cluster type must be one of: talos, kubeadm, k3s, k0s, rke2."
  }
}

variable "credentials_ref_name" {
  description = "Name of the secret containing Proxmox credentials"
  type        = string
  default     = "proxmox-credentials"
}

variable "qemu_guest_agent_image" {
  description = "QEMU guest agent image for Talos"
  type        = string
  default     = "ghcr.io/siderolabs/qemu-guest-agent:10.1.2"
}

variable "cloud_controller_manifests" {
  description = "List of cloud controller manager manifests to apply for Talos"
  type        = list(string)
  default = [
    "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/refs/heads/main/docs/deploy/cloud-controller-manager-daemonset.yml",
    "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml"
  ]
}

variable "cluster_api_dependencies" {
  description = "Dependencies for cluster-api resources (e.g., other modules that must be applied first)"
  type        = list(any)
  default     = []
}

variable "create_proxmox_secret" {
  description = "Whether to create the Proxmox credentials secret"
  type        = bool
  default     = true
}

variable "proxmox_url" {
  description = "Proxmox URL"
  type        = string
  default     = ""
}

variable "proxmox_secret" {
  description = "Proxmox API secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_token" {
  description = "Proxmox API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "List of SSH authorized keys for accessing cluster nodes (kubeadm, k3s, rke2)"
  type        = list(string)
  default     = []
}
