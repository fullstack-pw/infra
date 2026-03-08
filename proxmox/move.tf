moved {
  from = proxmox_vm_qemu.vm["k8s-tools.yaml"]
  to   = proxmox_vm_qemu.vm["k8s-clustermgmt.yaml"]
}
