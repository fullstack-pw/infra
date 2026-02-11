variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    pr-cks-backend-1 = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "argocd",
      "cloudnative-pg-operator",
      "postgres-cnpg",
      "observability-box",
    ]
  }
}

variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    pr-cks-backend-1 = {
      kubernetes_context        = "pr-cks-backend-1"
      crds_installed            = true
      argocd_ingress_class      = "traefik"
      argocd_domain             = "pr-cks-backend-1.argocd.fullstack.pw"
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      postgres_cnpg = {
        enable_superuser_access = true
        crds_installed          = true
        managed_roles = [
          { name = "root", login = true, replication = true }
        ]
        databases = []

        persistence_size               = "1Gi"
        ingress_host                   = "pr-cks-backend-1.postgres.fullstack.pw"
        use_istio                      = false
        export_credentials_secret_name = "pr-cks-backend-1-postgres-credentials"
      }
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
