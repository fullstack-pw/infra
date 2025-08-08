variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    home = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "immich"
    ]
    dev = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box"
    ]
    stg = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box"
    ]
    prod = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box"
    ]
    sandbox = [
      "externaldns",
      "cert_manager",
      "ingress_nginx",
      "observability"
    ]
    sandboxy = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "kubevirt",
      "longhorn"
    ]
    tools = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "postgres",
      "redis",
      "nats",
      #"observability-box",
      "gitlab_runner",
      "github_runner",
      "harbor",
      "minio",
      "vault"
    ]
    cluster-api = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "proxmox-talos-cluster"
    ]
  }
}

variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    home = {
      kubernetes_context = "home"
      install_crd        = true
      cert_manager_crd   = true
    }
    dev = {
      kubernetes_context = "dev"
      install_crd        = true
      cert_manager_crd   = true
    }
    stg = {
      kubernetes_context = "stg"
      install_crd        = true
      cert_manager_crd   = true
    }
    prod = {
      kubernetes_context = "prod"
      install_crd        = true
      cert_manager_crd   = true
    }
    sandbox = {
      kubernetes_context = "sandbox"
      install_crd        = true
      cert_manager_crd   = true
    }
    sandboxy = {
      kubernetes_context = "sandboxy"
      install_crd        = true
      cert_manager_crd   = true
    }
    tools = {
      kubernetes_context = "tools"
      install_crd        = true
      cert_manager_crd   = true
    }
    cluster-api = {
      kubernetes_context = "cluster-api"
      install_crd        = true
      cert_manager_crd   = true
      proxmox-talos-cluster = [
        {
          name                      = "testing-cluster"
          kubernetes_version        = "v1.33.0"
          control_plane_endpoint_ip = "192.168.1.100"
          ip_range_start            = "192.168.1.101"
          ip_range_end              = "192.168.1.110"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3", "8.8.4.4"]

          source_node   = "node03"
          template_id   = 103
          allowed_nodes = ["node03"]

          cp_replicas = 1
          wk_replicas = 2

          cp_disk_size = 20
          cp_memory    = 2048
          cp_cores     = 2
          wk_disk_size = 30
          wk_memory    = 4096
          wk_cores     = 2
        },
      ]
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
