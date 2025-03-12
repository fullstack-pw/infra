import {
  to = proxmox_vm_qemu.vm["dns.yaml"]
  id = "node01/qemu/100"
}

import {
  to = proxmox_vm_qemu.vm["haproxy.yaml"]
  id = "node01/qemu/101"
}

import {
  to = proxmox_vm_qemu.vm["k01.yaml"]
  id = "node01/qemu/102"
}

import {
  to = proxmox_vm_qemu.vm["k02.yaml"]
  id = "node01/qemu/103"
}

import {
  to = proxmox_vm_qemu.vm["k03.yaml"]
  id = "node01/qemu/104"
}

# TEMPORARILY REMOVE OR COMMENT OUT THESE IMPORTS
# import {
#   to = proxmox_vm_qemu.vm["boot-server.yaml"]
#   id = "node01/qemu/110"
# }
# 
# import {
#   to = proxmox_vm_qemu.vm["k8s-dev.yaml"]
#   id = "node02/qemu/110"
# }
# 
# import {
#   to = proxmox_vm_qemu.vm["k8s-stg.yaml"]
#   id = "node02/qemu/111"
# }
# 
# import {
#   to = proxmox_vm_qemu.vm["k8s-prod.yaml"]
#   id = "node02/qemu/112"
# }