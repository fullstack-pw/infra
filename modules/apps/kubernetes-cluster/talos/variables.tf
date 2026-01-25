variable "clusters" {
  description = "List of Talos clusters to create"
  type = list(object({
    name               = string
    kubernetes_version = optional(string, "v1.33.0")

    cp_replicas                 = optional(number, 3)
    control_plane_endpoint_ip   = string
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
  }))
}

variable "credentials_ref_name" {
  description = "Name of the Proxmox credentials secret reference"
  type        = string
  default     = "proxmox-credentials"
}

variable "qemu_guest_agent_image" {
  description = "QEMU guest agent Talos extension image"
  type        = string
  default     = "ghcr.io/siderolabs/qemu-guest-agent:9.1.1"
}

variable "cloud_controller_manifests" {
  description = "List of cloud controller manifests to deploy"
  type        = list(string)
  default = [
    "https://raw.githubusercontent.com/sergelogvinov/proxmox-cloud-controller-manager/main/docs/deploy/cloud-controller-manager.yml"
  ]
}

variable "core_module_namespaces" {
  description = "Dependency on core module namespaces"
  type        = any
  default     = []
}
