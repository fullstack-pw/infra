data "local_file" "yaml_files" {
  for_each = setsubtract(fileset("${path.module}/vms", "*.yaml"), ["k8s-home.yaml"])
  filename = "${path.module}/vms/${each.key}"
}

locals {
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
}

resource "proxmox_vm_qemu" "vm" {
  for_each = local.vm_configs

  name        = each.value.name
  target_node = each.value.target_node
  cores       = lookup(each.value, "cores", 1)
  sockets     = lookup(each.value, "sockets", 1)
  memory      = lookup(each.value, "memory", 1024)
  cpu_type    = lookup(each.value, "cpu_type", "host")
  onboot      = lookup(each.value, "onboot", true)
  tags        = "terraform"
  clone       = lookup(each.value, "clone", null)
  full_clone  = lookup(each.value, "full_clone", false)

  boot = lookup(each.value, "boot", null)

  agent = lookup(each.value, "agent", 0)

  vm_state = lookup(each.value, "vm_state", null)

  scsihw                 = lookup(each.value, "scsihw", "virtio-scsi-single")
  define_connection_info = lookup(each.value, "define_connection_info", false)
  automatic_reboot       = lookup(each.value, "automatic_reboot", true)

  ciuser     = lookup(each.value, "ciuser", null)
  cipassword = lookup(each.value, "cipassword", null)
  sshkeys    = lookup(each.value, "sshkeys", null)
  nameserver = lookup(each.value, "nameserver", null)
  ipconfig0  = lookup(each.value, "ipconfig0", null)
  skip_ipv6  = lookup(each.value, "skip_ipv6", false)

  dynamic "serial" {
    for_each = tobool(lookup(each.value, "serial", false)) ? [1] : []
    content {
      id = 0
    }
  }

  dynamic "disks" {
    for_each = contains(keys(each.value), "nested_disks") ? [each.value.nested_disks] : []
    content {
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
          dynamic "scsi1" {
            for_each = contains(keys(scsi.value), "scsi1") ? [scsi.value.scsi1] : []
            content {
              dynamic "passthrough" {
                for_each = contains(keys(scsi1.value), "passthrough") ? [scsi1.value.passthrough] : []
                content {
                  file                 = lookup(passthrough.value, "file", null)
                  backup               = lookup(passthrough.value, "backup", null)
                  discard              = lookup(passthrough.value, "discard", null)
                  emulatessd           = lookup(passthrough.value, "emulatessd", null)
                  iops_r_burst         = lookup(passthrough.value, "iops_r_burst", null)
                  iops_r_burst_length  = lookup(passthrough.value, "iops_r_burst_length", null)
                  iops_r_concurrent    = lookup(passthrough.value, "iops_r_concurrent", null)
                  iops_wr_burst        = lookup(passthrough.value, "iops_wr_burst", null)
                  iops_wr_burst_length = lookup(passthrough.value, "iops_wr_burst_length", null)
                  iops_wr_concurrent   = lookup(passthrough.value, "iops_wr_concurrent", null)
                  iothread             = lookup(passthrough.value, "iothread", null)
                  mbps_r_burst         = lookup(passthrough.value, "mbps_r_burst", null)
                  mbps_r_concurrent    = lookup(passthrough.value, "mbps_r_concurrent", null)
                  mbps_wr_burst        = lookup(passthrough.value, "mbps_wr_burst", null)
                  mbps_wr_concurrent   = lookup(passthrough.value, "mbps_wr_concurrent", null)
                  readonly             = lookup(passthrough.value, "readonly", null)
                  replicate            = lookup(passthrough.value, "replicate", null)
                  size                 = lookup(passthrough.value, "size", null)
                }
              }
            }
          }
        }
      }

      dynamic "ide" {
        for_each = contains(keys(disks.value), "ide") ? [disks.value.ide] : []
        content {
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

  dynamic "disk" {
    for_each = (!contains(keys(each.value), "nested_disks") && contains(keys(each.value), "disks")) ? (
      [for d in lookup(each.value, "disks", []) : d
      if !contains(keys(d), "cloudinit") || lookup(d, "cloudinit", false) == false]
    ) : []
    content {
      slot    = disk.value.slot
      type    = disk.value.type
      size    = contains(keys(disk.value), "size") ? disk.value.size : null
      storage = contains(keys(disk.value), "storage") ? disk.value.storage : null
      iso     = contains(keys(disk.value), "iso") ? disk.value.iso : null
      format  = lookup(disk.value, "format", null)
    }
  }

  dynamic "network" {
    for_each = contains(keys(each.value), "network") ? [each.value.network] : []
    content {
      model    = lookup(network.value, "model", "virtio")
      bridge   = network.value.bridge
      firewall = lookup(network.value, "firewall", true)
      id       = 0
    }
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      bootdisk,
      smbios
    ]
  }
}

