variable "namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "vault"
}

variable "chart_version" {
  description = "Version of the Vault Helm chart"
  type        = string
  default     = "0.29.1"
}

variable "force_update" {
  description = "Force resource updates through replacement"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "ui_enabled" {
  description = "Enable the Vault UI"
  type        = bool
  default     = true
}

variable "data_storage_enabled" {
  description = "Enable persistence for Vault"
  type        = bool
  default     = true
}

variable "data_storage_storage_class" {
  description = "Storage class for Vault data"
  type        = string
  default     = "hostpath"
}

variable "ingress_enabled" {
  description = "Enable ingress for Vault"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name for Vault ingress"
  type        = string
  default     = "nginx"
}

variable "ingress_annotations" {
  description = "Annotations for Vault ingress"
  type        = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname" = "vault.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
}

variable "ingress_host" {
  description = "Host for Vault ingress"
  type        = string
  default     = "vault.fullstack.pw"
}

variable "tls_secret_name" {
  description = "TLS secret name for Vault ingress"
  type        = string
  default     = "vault-tls"
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Vault Initialization variables
variable "initialize_vault" {
  description = "Whether to initialize Vault with KV store and Kubernetes auth"
  type        = bool
  default     = true
}

variable "kv_path" {
  description = "Path for the KV secrets engine"
  type        = string
  default     = "kv"
}

variable "kubernetes_host" {
  description = "Kubernetes API server endpoint for Vault auth configuration"
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "kubernetes_ca_cert" {
  description = "Kubernetes CA certificate for Vault auth configuration"
  type        = string
  default     = ""
  sensitive   = true
}

variable "token_reviewer_jwt" {
  description = "Service account JWT for Vault auth configuration"
  type        = string
  default     = ""
  sensitive   = true
}

variable "initial_secrets" {
  description = "Map of initial secrets to create in Vault (path => map of key/values)"
  type        = map(map(string))
  default     = {}
  sensitive   = false
}

variable "policies" {
  description = "Map of policies to create in Vault (name => policy HCL)"
  type        = map(string)
  default     = {}
}
