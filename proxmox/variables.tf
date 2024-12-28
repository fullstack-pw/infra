

variable "vm_configs" {
  default = []
}

variable "proxmox_password" {}

# Define the network configuration
variable "network_config" {
  default = {
    dns = "192.168.1.3"
    k01 = "192.168.1.101"
    k02 = "192.168.1.102"
    k03 = "192.168.1.103"
    k8s = "192.168.1.4"
  }
}

locals {
  vm_configs = {
    for file, content in data.local_file.yaml_files :
    file => yamldecode(content.content)
  }
}
