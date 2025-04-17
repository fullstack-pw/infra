variable "create" {
  description = "Whether to create the namespace"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the namespace"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the namespace"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to apply to the namespace"
  type        = map(string)
  default     = {}
}

variable "add_cluster_secretstore_label" {
  description = "Add label for ClusterSecretStore to target this namespace"
  type        = bool
  default     = false
}

variable "needs_secrets" {
  description = "Add label for ExternalSecrets to target this namespace"
  type        = bool
  default     = false
}
