# modules/apps/proxmox-talos-cluster/variables.tf

variable "clusters" {
  description = "List of Talos clusters to create"
  type = list(object({
    # Basic cluster configuration
    name               = string
    kubernetes_version = optional(string, "v1.33.0")

    # Control plane configuration
    cp_replicas                 = optional(number, 3)
    control_plane_endpoint_ip   = string
    control_plane_endpoint_port = optional(number, 6443)

    # Worker configuration
    wk_replicas = optional(number, 3)

    # Network configuration
    ip_range_start = string
    ip_range_end   = string
    gateway        = string
    prefix         = number
    dns_servers    = optional(list(string), ["192.168.1.3", "8.8.4.4"])

    # Proxmox configuration
    source_node       = string
    template_id       = number
    allowed_nodes     = optional(list(string), [])
    memory_adjustment = optional(number, 0)

    # Control plane machine specs
    cp_disk_size = optional(number, 20)
    cp_memory    = optional(number, 2048)
    cp_cores     = optional(number, 2)
    cp_sockets   = optional(number, 1)

    # Worker machine specs
    wk_disk_size = optional(number, 20)
    wk_memory    = optional(number, 2048)
    wk_cores     = optional(number, 2)
    wk_sockets   = optional(number, 1)

    # Network settings
    network_bridge = optional(string, "vmbr0")
    network_model  = optional(string, "virtio")

    # Disk settings
    disk_format  = optional(string, "qcow2")
    install_disk = optional(string, "/dev/sda")

    # VM settings
    skip_cloud_init_status = optional(bool, true)
    skip_qemu_guest_agent  = optional(bool, true)
    provider_id_injection  = optional(bool, true)
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
}

variable "namespace" {
  description = "Namespace for cluster-api resources"
  type        = string
  default     = "clusters"
}

variable "credentials_ref_name" {
  description = "Name of the secret containing Proxmox credentials"
  type        = string
  default     = "proxmox-credentials"
}

variable "qemu_guest_agent_image" {
  description = "QEMU guest agent image"
  type        = string
  default     = "ghcr.io/siderolabs/qemu-guest-agent:10.1.2"
}

variable "cloud_controller_manifests" {
  description = "List of cloud controller manager manifests to apply"
  type        = list(string)
  default = [
    #"https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/main/docs/deploy/cloud-controller-manager.yml",
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
  description = "Proxmox username"
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
