# Read YAML files for VMs
data "local_file" "yaml_files" {
  for_each = fileset("${path.module}/vms", "*.yaml")
  filename = "${path.module}/vms/${each.key}"
}

locals {
  # Parse YAML files into a map of VM definitions, excluding the ones we're migrating
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
    if !contains([], file)
  }
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
  
  # Clone settings
  clone       = lookup(each.value, "clone", null)
  full_clone  = lookup(each.value, "full_clone", false)
  
  # Boot order if specified
  boot        = lookup(each.value, "boot", null)
  
  # Agent settings
  agent       = lookup(each.value, "agent", 0)
  
  # VM state (if specified)
  vm_state    = lookup(each.value, "vm_state", null)
  
  # Other standard configs
  scsihw                  = lookup(each.value, "scsihw", "virtio-scsi-single")
  define_connection_info  = lookup(each.value, "define_connection_info", false)
  automatic_reboot        = lookup(each.value, "automatic_reboot", true)
  
  # Cloud-init settings
  ciuser     = lookup(each.value, "ciuser", null)
  cipassword = lookup(each.value, "cipassword", null)
  sshkeys    = lookup(each.value, "sshkeys", null)
  nameserver = lookup(each.value, "nameserver", null)
  ipconfig0  = lookup(each.value, "ipconfig0", null)
  skip_ipv6  = lookup(each.value, "skip_ipv6", false)
  
  # Add serial device if needed
  dynamic "serial" {
    for_each = tobool(lookup(each.value, "serial", false)) ? [1] : []
    content {
      id = 0
    }
  }
  
  # Choose disk format based on what's in the YAML
  # Use 'disks' block if nested_disks is defined
  dynamic "disks" {
    for_each = contains(keys(each.value), "nested_disks") ? [each.value.nested_disks] : []
    content {
      # SCSI disks
      dynamic "scsi" {
        for_each = contains(keys(disks.value), "scsi") ? [disks.value.scsi] : []
        content {
          dynamic "scsi0" {
            for_each = contains(keys(scsi.value), "scsi0") ? [scsi.value.scsi0] : []
            content {
              dynamic "disk" {
                for_each = contains(keys(scsi0.value), "disk") ? [scsi0.value.disk] : []
                content {
                  storage = lookup(disk.value, "storage", null)
                  size    = lookup(disk.value, "size", null)
                  format  = lookup(disk.value, "format", null)
                }
              }
            }
          }
        }
      }
      
      # IDE disks
      dynamic "ide" {
        for_each = contains(keys(disks.value), "ide") ? [disks.value.ide] : []
        content {
          # CloudInit on IDE1
          dynamic "ide1" {
            for_each = contains(keys(ide.value), "ide1") && contains(keys(ide.value.ide1), "cloudinit") ? [ide.value.ide1] : []
            content {
              dynamic "cloudinit" {
                for_each = contains(keys(ide1.value), "cloudinit") ? [ide1.value.cloudinit] : []
                content {
                  storage = lookup(cloudinit.value, "storage", null)
                }
              }
            }
          }
        }
      }
    }
  }
  
  # Use 'disk' blocks if no nested_disks but regular disks are defined
  dynamic "disk" {
    for_each = (!contains(keys(each.value), "nested_disks") && contains(keys(each.value), "disks")) ? (
      [for d in lookup(each.value, "disks", []) : d
       if !contains(keys(d), "cloudinit") || lookup(d, "cloudinit", false) == false]
    ) : []
    content {
      slot      = disk.value.slot
      type      = disk.value.type
      size      = contains(keys(disk.value), "size") ? disk.value.size : null
      storage   = contains(keys(disk.value), "storage") ? disk.value.storage : null
      iso       = contains(keys(disk.value), "iso") ? disk.value.iso : null
      format    = lookup(disk.value, "format", null)
    }
  }
  
  # Network configuration
  dynamic "network" {
    for_each = contains(keys(each.value), "network") ? [each.value.network] : []
    content {
      model     = lookup(network.value, "model", "virtio")
      bridge    = network.value.bridge
      firewall  = lookup(network.value, "firewall", true)
      id        = 0
    }
  }
  
  lifecycle {
    # Ignore changes to specific attributes that might change outside of Terraform
    ignore_changes = [
      network[0].macaddr,
      bootdisk,
      linked_vmid,
      reboot_required,
      unused_disk,
      smbios
    ]
  }
}

