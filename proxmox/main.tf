terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.1.2:8006/api2/json"
  pm_user         = "root@pam"
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
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

# Read YAML files
data "local_file" "yaml_files" {
  for_each = fileset("${path.module}/vms", "*.yaml")
  filename = "${path.module}/vms/${each.key}"
}

# Decode YAML content
locals {
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
}

# Create VMs dynamically
resource "proxmox_vm_qemu" "vm" {
  for_each = local.vm_configs

  name       = each.value.name
  cores      = each.value.cores
  memory     = each.value.memory
  cpu_type   = each.value.cpu_type
  onboot     = each.value.onboot
  full_clone = false
  scsihw     = "virtio-scsi-single"

  # Dynamic disks block
  # Dynamic scsi disks
  dynamic "scsi" {
    for_each = [for disk in each.value.disks : disk if disk.type == "scsi"]
    content {
      scsi0 {
        disk {
          size    = lookup(scsi.value, "size", null)
          storage = lookup(scsi.value, "storage", null)
          format  = lookup(scsi.value, "format", null)
        }
      }
    }
  }

  # Dynamic ide disks
  dynamic "ide" {
    for_each = [for disk in each.value.disks : disk if disk.type == "ide"]
    content {
      ide2 {
        cdrom {
          iso = lookup(ide.value, "iso", null)
        }
      }
    }
  }

  network {
    bridge   = each.value.network.bridge
    firewall = each.value.network.firewall
    model    = each.value.network.model
    id       = 0
  }
}
