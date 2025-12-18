variable "namespace" {
  description = "Namespace for ClusterAPI operator"
  type        = string
  default     = "capi-operator-system"
}

variable "operator_version" {
  description = "ClusterAPI operator chart version"
  type        = string
  default     = "0.24.1"
}

variable "values_files" {
  description = "Values files for Helm chart"
  type        = list(string)
  default     = []
}

# Provider enablement flags
variable "enable_core_provider" {
  description = "Enable core Cluster API provider (required for all other providers)"
  type        = bool
  default     = true
}

variable "enable_proxmox_provider" {
  description = "Enable Proxmox infrastructure provider"
  type        = bool
  default     = true
}

variable "enable_talos_provider" {
  description = "Enable Talos bootstrap and control-plane providers"
  type        = bool
  default     = true
}

variable "enable_k3s_provider" {
  description = "Enable K3s bootstrap and control-plane providers"
  type        = bool
  default     = false
}

variable "enable_kubeadm_provider" {
  description = "Enable Kubeadm bootstrap and control-plane providers"
  type        = bool
  default     = false
}

variable "enable_ipam_provider" {
  description = "Enable in-cluster IPAM provider"
  type        = bool
  default     = true
}

# Provider versions
variable "core_provider_version" {
  description = "Core Cluster API provider version"
  type        = string
  default     = "v1.12.0"
}

variable "proxmox_provider_version" {
  description = "Proxmox provider version (CAPMOX - ionos-cloud)"
  type        = string
  default     = "v0.7.5"
}

variable "talos_bootstrap_version" {
  description = "Talos bootstrap provider version"
  type        = string
  default     = "v0.6.10"
}

variable "talos_controlplane_version" {
  description = "Talos control-plane provider version"
  type        = string
  default     = "v0.5.11"
}

variable "k3s_bootstrap_version" {
  description = "K3s bootstrap provider version"
  type        = string
  default     = "v0.3.0"
}

variable "k3s_controlplane_version" {
  description = "K3s control-plane provider version"
  type        = string
  default     = "v0.3.0"
}

variable "kubeadm_bootstrap_version" {
  description = "Kubeadm bootstrap provider version (core CAPI)"
  type        = string
  default     = "v1.12.0-rc.0"
}

variable "kubeadm_controlplane_version" {
  description = "Kubeadm control-plane provider version (core CAPI)"
  type        = string
  default     = "v1.12.0-rc.0"
}

variable "ipam_version" {
  description = "In-cluster IPAM provider version"
  type        = string
  default     = "v1.0.3"
}

variable "proxmox_secret_name" {
  description = "Name of Kubernetes secret containing Proxmox credentials"
  type        = string
  default     = "proxmox-credentials"
}

variable "proxmox_url" {
  description = "Proxmox API URL"
  type        = string
  default     = ""
}

variable "proxmox_secret" {
  description = "Proxmox API secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_token" {
  description = "Proxmox API token ID"
  type        = string
  default     = ""
  sensitive   = true
}
