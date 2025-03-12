variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    dev = {
      kubernetes_context = "dev"
    }
    stg = {
      kubernetes_context = "stg"
    }
    prod = {
      kubernetes_context = "prod"
    }
  }
}
variable "kubeconfig_path" {
  default = "~/.kube/config"
}
variable "vault_addr" {
  default = "https://vault.fullstack.pw"
}
variable "vault_token" {}
variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    dev     = ["externaldns", "cert_manager", "external_secrets", "otel_collector"]
    stg     = ["externaldns", "cert_manager", "external_secrets"]
    prod    = ["externaldns", "cert_manager", "external_secrets"]
    sandbox = ["externaldns"]
    runners = ["externaldns"]
  }
}

locals {
  workload = var.workload[terraform.workspace]
}
