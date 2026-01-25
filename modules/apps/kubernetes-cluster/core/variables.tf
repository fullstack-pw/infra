variable "clusters" {
  description = "List of cluster configurations"
  type = list(object({
    name = string
  }))
}

variable "create_proxmox_secret" {
  description = "Whether to create Proxmox credentials secret"
  type        = bool
  default     = true
}

variable "credentials_ref_name" {
  description = "Name of the credentials secret reference"
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
  sensitive   = true
  default     = ""
}

variable "proxmox_token" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cluster_api_dependencies" {
  description = "Dependencies for Cluster API resources"
  type        = list(any)
  default     = []
}
