

variable "vm_configs" {
  default = []
}

variable "proxmox_password" {}

# Define the network configuration
variable "network_config" {
  default = {
    dns = "192.168.1.3"
    k01 = "192.168.1.101"
    k02 = "192.168.1.102"
    k03 = "192.168.1.103"
    k8s = "192.168.1.4"
  }
}

locals {
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
}

variable "vm_count" {
  type        = number
  description = "Number of VM replicas per cluster environment"
  default     = 1
}

variable "vm_storage" {
  type        = string
  description = "Name of the Proxmox storage pool to use"
  default     = "local-lvm"
}

variable "vm_image" {
  type        = string
  description = "Name or ID of the VM template or ISO"
  default     = "ubuntu-2204-template"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge to use"
  default     = "vmbr0"
}

variable "vcpus" {
  type        = number
  description = "Number of vCPUs per VM"
  default     = 2
}

variable "memory" {
  type        = number
  description = "RAM in MB per VM"
  default     = 4096
}
