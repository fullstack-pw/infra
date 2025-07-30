// proxmox/variables.tf

# Required variables
variable "PROXMOX_PASSWORD" {
  description = "Password for Proxmox API authentication"
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
# Network configuration
variable "network_config" {
  description = "Map of network configurations for VMs"
  type        = map(string)
  default = {
    dns = "192.168.1.3"
    k01 = "192.168.1.101"
    k02 = "192.168.1.102"
    k03 = "192.168.1.103"
    k8s = "192.168.1.4"
  }
}
variable "vm_defaults" {
  description = "Default values for VM resources"
  type = object({
    cpu_type         = string
    sockets          = number
    cores            = number
    memory           = number
    disk_size        = string
    storage_location = string
    network_bridge   = string
  })
  default = {
    cpu_type         = "host"
    sockets          = 1
    cores            = 1
    memory           = 1024
    disk_size        = "20G"
    storage_location = "local-lvm"
    network_bridge   = "vmbr0"
  }
}

variable "ssh_keys" {
  description = "SSH public keys to add to cloud-init VMs"
  type        = list(string)
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"
  ]
}
variable "cloud_init_credentials" {
  description = "Default credentials for cloud-init VMs"
  type = object({
    username = string
    password = string
  })
  default = {
    username = "suporte"
    password = "sistema"
  }
}

variable "proxmox_isos" {
  description = "Details about available Proxmox ISOs"
  type = map(object({
    path    = string
    version = string
  }))
  default = {
    ubuntu_23_10 = {
      path    = "local:iso/ubuntu-23.10-live-server-amd64.iso"
      version = "23.10"
    }
    ubuntu_24_04 = {
      path    = "local:iso/ubuntu-24.04.1-live-server-amd64.iso"
      version = "24.04"
    }
    proxmox_8_3 = {
      path    = "local:iso/proxmox-ve_8.3-1.iso"
      version = "8.3-1"
    }
  }
}
variable "vm_templates" {
  description = "Available VM templates for cloning"
  type        = map(string)
  default = {
    ubuntu24_cloudinit = "ubuntu24-cloudinit"
    ubuntu24_standard  = "ubuntu24-template"
  }
}
