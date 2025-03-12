// proxmox/outputs.tf

# Output information about provisioned VMs
output "vm_ips" {
  description = "IP addresses of all provisioned VMs"
  value = {
    for name, vm in proxmox_vm_qemu.vm :
    name => vm.ipconfig0
  }
}

output "k8s_nodes" {
  description = "Kubernetes nodes details"
  value = {
    for name, vm in proxmox_vm_qemu.vm :
    name => {
      ip = vm.ipconfig0
      node = vm.target_node
    }
    if startswith(name, "k8s-") || startswith(name, "k0")
  }
}

# This helps with Ansible inventory generation
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    k3s_clusters = {
      dev = [for name, vm in proxmox_vm_qemu.vm : vm.ipconfig0 if name == "k8s-dev.yaml"]
      stg = [for name, vm in proxmox_vm_qemu.vm : vm.ipconfig0 if name == "k8s-stg.yaml"]
      prod = [for name, vm in proxmox_vm_qemu.vm : vm.ipconfig0 if name == "k8s-prod.yaml"]
    }
    pxe_server = [for name, vm in proxmox_vm_qemu.vm : vm.ipconfig0 if name == "boot-server.yaml"]
  }
}