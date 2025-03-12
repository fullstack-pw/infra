# Read YAML files for VMs
data "local_file" "yaml_files" {
  for_each = fileset("${path.module}/vms", "*.yaml")
  filename = "${path.module}/vms/${each.key}"
}

locals {
  # Parse YAML files into a map of VM definitions
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
  
  # Define which nodes need serial devices (for cloud-init, etc.)
  nodes_with_serial = [
    "boot-server"
  ]
  
  # Define which nodes need cloudinit disks
  nodes_with_cloudinit = [
    "boot-server",
    "k8s-dev",
    "k8s-stg", 
    "k8s-prod"
  ]
}

# Create VMs dynamically from YAML files
resource "proxmox_vm_qemu" "vm" {
  for_each = local.vm_configs

  # Basic VM configuration
  name        = each.value.name
  target_node = each.value.target_node
  cores       = lookup(each.value, "cores", 1)
  sockets     = lookup(each.value, "sockets", 1)
  memory      = lookup(each.value, "memory", 1024)
  cpu_type    = lookup(each.value, "cpu_type", "host")
  onboot      = lookup(each.value, "onboot", true)
  full_clone  = false
  
  # Other standard configs
  scsihw                  = "virtio-scsi-single"
  define_connection_info  = false
  agent                   = 0  # Keep existing setting
  automatic_reboot        = true
  
  # Legacy disk configuration
  dynamic "disk" {
    for_each = lookup(each.value, "disks", [])
    content {
      slot      = disk.value.slot
      type      = disk.value.type
      size      = strcontains(disk.value.slot, "scsi") ? disk.value.size : null
      storage   = strcontains(disk.value.slot, "scsi") ? disk.value.storage : null
      iso       = strcontains(disk.value.slot, "ide") ? lookup(disk.value, "iso", null) : null
      format    = lookup(disk.value, "format", null)
    }
  }
  
  # Network configuration
  network {
    bridge   = each.value.network.bridge
    firewall = lookup(each.value.network, "firewall", true)
    model    = lookup(each.value.network, "model", "virtio")
    id       = 0
  }
  
  # IP configuration
  ipconfig0 = lookup(each.value, "ipconfig0", null)
}

# Keep the existing separate resources for the already managed VMs
resource "proxmox_vm_qemu" "boot_server" {
  name        = "boot-server"
  target_node = "node01"
  agent       = 1
  cores       = 2
  memory      = 1024
  boot        = "order=scsi0"
  clone       = "ubuntu24-cloudinit"
  scsihw      = "virtio-scsi-single"
  vm_state    = "stopped"
  automatic_reboot = true

  nameserver = "192.168.1.3"
  ipconfig0  = "ip=192.168.1.10/24,gw=192.168.1.1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "suporte"
  cipassword = "sistema"
  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "slowdata"
          size    = "50G" 
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "slowdata"
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}

resource "proxmox_vm_qemu" "k8s_dev" {
  name        = "k8s-dev"
  target_node = "node02"
  agent       = 1
  cores       = 4
  memory      = 8192
  boot        = "order=scsi0"
  clone       = "ubuntu24-template"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  nameserver = "192.168.1.3"
  ipconfig0  = "ip=192.168.1.12/24,gw=192.168.1.1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "suporte"
  cipassword = "sistema"
  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "30G" 
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}

resource "proxmox_vm_qemu" "k8s_stg" {
  name        = "k8s-stg"
  target_node = "node02"
  agent       = 1
  cores       = 4
  memory      = 8192
  boot        = "order=scsi0"
  clone       = "ubuntu24-template"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  nameserver = "192.168.1.3"
  ipconfig0  = "ip=192.168.1.13/24,gw=192.168.1.1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "suporte"
  cipassword = "sistema"
  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "30G" 
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}

resource "proxmox_vm_qemu" "k8s_prod" {
  name        = "k8s-prod"
  target_node = "node02"
  agent       = 1
  cores       = 4
  memory      = 8192
  boot        = "order=scsi0"
  clone       = "ubuntu24-template"
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  nameserver = "192.168.1.3"
  ipconfig0  = "ip=192.168.1.14/24,gw=192.168.1.1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "suporte"
  cipassword = "sistema"
  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"

  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "30G" 
        }
      }
    }
    ide {
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}