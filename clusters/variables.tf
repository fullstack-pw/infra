variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    dev = {
      kubernetes_context = "dev"
      externalsecret     = "default"
    }
    stg = {
      kubernetes_context = "stg"
      externalsecret     = "default"
    }
    prod = {
      kubernetes_context = "prod"
      externalsecret     = "default"
    }
    runners = {
      kubernetes_context = "runners"
      externalsecret     = "actions-runner-system"
    }
    sandbox = {
      kubernetes_context = "sandbox"
      externalsecret     = "default"
    }
    tools = {
      kubernetes_context = "tools"
      externalsecret     = "default"
    }
  }
}
variable "kubeconfig_path" {
  default = "~/.kube/config"
}
variable "vault_addr" {
  default = "https://vault.fullstack.pw"
}
variable "VAULT_TOKEN" {}


variable "kubernetes_ca_cert" {
  description = "Kubernetes CA certificate for Vault auth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "token_reviewer_jwt" {
  description = "Service account JWT for Vault auth"
  type        = string
  sensitive   = true
  default     = ""
}

variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    dev     = ["externaldns", "cert_manager", "external_secrets", "otel_collector"]
    stg     = ["externaldns", "cert_manager", "external_secrets"]
    prod    = ["externaldns", "cert_manager", "external_secrets"]
    sandbox = ["externaldns", "cert_manager", "ingress_nginx", "minio", "observability", "registry", "vault"]
    runners = ["external_secrets", "gitlab_runner", "github_runner"]
  }
}

locals {
  workload = var.workload[terraform.workspace]
}
