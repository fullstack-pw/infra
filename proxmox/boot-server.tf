resource "proxmox_vm_qemu" "boot_server" {
  #vmid        = 110
  name        = "boot-server"
  target_node = "node01"
  agent       = 1
  cores       = 2
  memory      = 1024
  boot        = "order=scsi0" # has to be the same as the OS disk of the template
  clone       = "ubuntu24-cloudinit" # The name of the template
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
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
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