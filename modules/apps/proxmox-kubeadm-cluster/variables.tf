variable "clusters" {
  description = "List of Kubeadm clusters to create"
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

    # CNI configuration
    cni_type         = optional(string, "cilium") # cilium, calico, or flannel
    cni_manifest_url = optional(string, "https://raw.githubusercontent.com/cilium/cilium/v1.14.5/install/kubernetes/quick-install.yaml")

    # Network configuration
    ip_range_start = string
    ip_range_end   = string
    gateway        = string
    prefix         = number
    dns_servers    = optional(list(string), ["192.168.1.3", "8.8.4.4"])
    pod_cidr       = optional(string, "10.244.0.0/16")
    service_cidr   = optional(string, "10.96.0.0/12")

    # Proxmox configuration
    source_node       = string
    template_id       = number
    allowed_nodes     = optional(list(string), [])
    memory_adjustment = optional(number, 0)

    # Control plane machine specs
    cp_disk_size = optional(number, 50)
    cp_memory    = optional(number, 4096)
    cp_cores     = optional(number, 2)
    cp_sockets   = optional(number, 1)

    # Worker machine specs
    wk_disk_size = optional(number, 100)
    wk_memory    = optional(number, 8192)
    wk_cores     = optional(number, 4)
    wk_sockets   = optional(number, 1)

    # Network settings
    network_bridge = optional(string, "vmbr0")
    network_model  = optional(string, "virtio")

    # Disk settings
    disk_format = optional(string, "qcow2")

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
  description = "DEPRECATED: Each cluster now uses its own name as the namespace. This variable is kept for backward compatibility but is not used."
  type        = string
  default     = "clusters"
}

variable "credentials_ref_name" {
  description = "Name of the secret containing Proxmox credentials"
  type        = string
  default     = "proxmox-credentials"
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
  description = "Proxmox secret"
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
  description = "List of SSH authorized keys for accessing cluster nodes"
  type        = list(string)
  default     = []
}
