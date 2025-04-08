variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    dev     = ["externaldns", "cert_manager", "external_secrets", "otel_collector", "fluent"]
    stg     = ["externaldns", "cert_manager", "external_secrets", "otel_collector", "fluent"]
    prod    = ["externaldns", "cert_manager", "external_secrets", "otel_collector", "fluent"]
    sandbox = ["externaldns", "cert_manager", "ingress_nginx", "minio", "observability", "vault", "fluent", "harbor"]
    runners = ["external_secrets", "gitlab_runner", "github_runner", "runner_secrets"]
    tools   = ["externaldns", "cert_manager", "external_secrets", "postgres", "redis", "nats", "fluent"]
  }
}

locals {
  workload = var.workload[terraform.workspace]
}
variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    dev = {
      kubernetes_context = "dev"
      externalsecret     = "default"
      install_crd        = true
      cert_manager_crd   = true
    }
    stg = {
      kubernetes_context = "stg"
      externalsecret     = "default"
      install_crd        = true
      cert_manager_crd   = true
    }
    prod = {
      kubernetes_context = "prod"
      externalsecret     = "default"
      install_crd        = true
      cert_manager_crd   = true
    }
    runners = {
      kubernetes_context = "runners"
      externalsecret     = "actions-runner-system"
      install_crd        = true
    }
    sandbox = {
      kubernetes_context = "sandbox"
      externalsecret     = "default"
      install_crd        = true
      cert_manager_crd   = true
    }
    tools = {
      kubernetes_context = "quick-harbor"
      externalsecret     = "default"
      install_crd        = true
      cert_manager_crd   = true
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

variable "sops_age_key" {
  description = "Content of the SOPS age private key for CI/CD runners"
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_runner_secrets" {
  description = "Whether to create secrets for CI/CD runners"
  type        = bool
  default     = true
}

variable "create_github_runner_secret" {
  description = "Whether to create an age key secret for GitHub Actions runners"
  type        = bool
  default     = true
}

variable "create_gitlab_runner_secret" {
  description = "Whether to create an age key secret for GitLab runners"
  type        = bool
  default     = true
}
