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
