variable "namespace" {
  description = "Namespace for external-secrets"
  type        = string
  default     = "external-secrets"
}

variable "chart_version" {
  description = "External Secrets Helm chart version"
  type        = string
  default     = "0.12.1"
}

variable "timeout" {
  description = "Helm release timeout"
  type        = number
  default     = 120
}

variable "vault_token" {
  description = "Vault token for authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_addr" {
  description = "Vault address"
  type        = string
  default     = "https://vault.fullstack.pw"
}

variable "vault_path" {
  description = "Vault secrets path"
  type        = string
  default     = "kv/data/cluster-secret-store/secrets"
}

variable "refresh_time" {
  description = "How often to refresh the secrets"
  type        = string
  default     = "1m"
}

variable "refresh_interval" {
  description = "Refresh interval for external secrets"
  type        = string
  default     = "1m"
}

variable "namespace_selectors" {
  description = "Labels to select namespaces for ClusterExternalSecret"
  type        = map(string)
  default = {
    "kubernetes.io/metadata.name" = "default"
  }
}

variable "secret_data" {
  description = "Secret data configuration"
  type = list(object({
    secretKey = string
    remoteRef = object({
      key      = string
      property = optional(string)
    })
  }))
  default = []
}

variable "install_crd" {
  description = "Whether to install External Secrets CRDs"
  type        = bool
  default     = false
}

variable "namespace_selector_type" {
  description = "Type of namespace selector to use: 'name' for specific namespace name, 'label' for label selector"
  type        = string
  default     = "label"
  validation {
    condition     = contains(["name", "label"], var.namespace_selector_type)
    error_message = "Namespace selector type must be either 'name' or 'label'."
  }
}

variable "namespace_selector_label" {
  description = "Label key-value pair for selecting namespaces when namespace_selector_type is 'label'"
  type = object({
    key   = string
    value = string
  })
  default = {
    key   = "needs-cluster-secrets"
    value = "true"
  }
}
