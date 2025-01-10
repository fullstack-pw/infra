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
  sockets = each.value.sockets
  memory     = each.value.memory
  target_node = each.value.target_node
  cpu_type   = each.value.cpu_type
  onboot     = each.value.onboot
  full_clone = false
  scsihw     = "virtio-scsi-single"
  define_connection_info = false

  # Generate one "disk {...}" block per disk in the YAML
  dynamic "disk" {
    # for_each = each.value.disks
    for_each = [for d in each.value.disks : d]
    content {
      slot      = disk.value.slot
      type    = disk.value.type
      size    = strcontains(disk.value.slot, "scsi") ? disk.value.size : null
      storage = strcontains(disk.value.slot, "scsi") ? disk.value.storage : null
      iso     = strcontains(disk.value.slot, "ide")  ? lookup(disk.value, "iso", null) : null

      # If the user might specify format
      format  = disk.value.format
    }
  }

  network {
    bridge   = each.value.network.bridge
    firewall = each.value.network.firewall
    model    = each.value.network.model
    id       = 0
  }

  ipconfig0 = each.value.ipconfig0
  clone = each.value.template
}
