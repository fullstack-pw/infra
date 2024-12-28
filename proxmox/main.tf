# Read YAML files
data "local_file" "yaml_files" {
  for_each = fileset("${path.module}/vms", "*.yaml")
  filename = "${path.module}/vms/${each.key}"
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
