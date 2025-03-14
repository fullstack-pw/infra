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
    "kubernetes.io/metadata.name" = "github-runner"
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
  default = [
    {
      secretKey = "KUBECONFIG"
      remoteRef = {
        key      = "KUBECONFIG"
        property = "data.KUBECONFIG"
      }
      }, {
      secretKey = "GITHUB_PAT"
      remoteRef = {
        key      = "GITHUB_PAT"
        property = "data.GITHUB_PAT"
      }
      }, {
      secretKey = "TF_VAR_PROXMOX_PASSWORD"
      remoteRef = {
        key      = "TF_VAR_PROXMOX_PASSWORD"
        property = "data.TF_VAR_PROXMOX_PASSWORD"
      }
      }, {
      secretKey = "AWS_ACCESS_KEY_ID"
      remoteRef = {
        key      = "AWS_ACCESS_KEY_ID"
        property = "data.AWS_ACCESS_KEY_ID"
      }
      }, {
      secretKey = "AWS_SECRET_ACCESS_KEY"
      remoteRef = {
        key      = "AWS_SECRET_ACCESS_KEY"
        property = "data.AWS_SECRET_ACCESS_KEY"
      }
    }
  ]
}

