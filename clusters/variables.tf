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
      "teleport-agent",
      "dev-postgres"
      #"observability-box"
    ]
    stg = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      #"observability-box"
    ]
    prod = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      #"observability-box"
    ]
    sandboxy = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "kubevirt",
      "longhorn",
      "teleport-agent"
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
      "vault",
      "teleport-agent"
    ]
    observability = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability"
    ]
    cluster-api = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "proxmox-talos-cluster"
    ]
    # homologate-cluster-api = [
    #   "externaldns",
    #   "cert_manager",
    #   "external_secrets",
    #   "proxmox-talos-cluster"
    # ]
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
      teleport = {
        apps = {
          "dev-ascii" = "http://ascii-frontend.default.svc.cluster.local"
          "dev-cks"   = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        roles = "kube,app,db"
        databases = {
          "dev-postgres" = "dev.postgres.fullstack.pw:5432"
        }
      }
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
    sandboxy = {
      kubernetes_context = "sandboxy"
      install_crd        = true
      cert_manager_crd   = true
      teleport = {
        apps = {
          "longhorn" = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
        }
        databases = {}
        roles     = "kube,app"
      }
    }
    tools = {
      kubernetes_context = "tools"
      install_crd        = true
      cert_manager_crd   = true
      teleport = {
        apps = {
          "harbor" = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"  = "http://vault.vault.svc.cluster.local:8200"
          "minio"  = "http://minio-console.default.svc.cluster.local:9001"
        }
        databases = {}
        roles     = "kube,app"
      }
    }
    observability = {
      kubernetes_context = "observability"
      install_crd        = false
      cert_manager_crd   = false
    }
    cluster-api = {
      kubernetes_context = "cluster-api"
      install_crd        = true
      cert_manager_crd   = true
      # proxmox-talos-cluster = [
      #   {
      #     name                      = "testing-cluster"
      #     kubernetes_version        = "v1.33.0"
      #     control_plane_endpoint_ip = "192.168.1.100"
      #     ip_range_start            = "192.168.1.101"
      #     ip_range_end              = "192.168.1.110"
      #     gateway                   = "192.168.1.1"
      #     prefix                    = 24
      #     dns_servers               = ["192.168.1.3", "8.8.4.4"]

      #     source_node   = "node03"
      #     template_id   = 103
      #     allowed_nodes = ["node03"]

      #     cp_replicas = 1
      #     wk_replicas = 2

      #     cp_disk_size = 20
      #     cp_memory    = 2048
      #     cp_cores     = 2
      #     wk_disk_size = 30
      #     wk_memory    = 4096
      #     wk_cores     = 2
      #   },
      # ]
    }
    # homologate-cluster-api = {
    #   kubernetes_context = "homologate-cluster-api"
    #   install_crd        = true
    #   cert_manager_crd   = true
    #   # proxmox-talos-cluster = [
    #   #   {
    #   #     name                      = "testing-cluster"
    #   #     kubernetes_version        = "v1.33.0"
    #   #     control_plane_endpoint_ip = "192.168.1.100"
    #   #     ip_range_start            = "192.168.1.101"
    #   #     ip_range_end              = "192.168.1.110"
    #   #     gateway                   = "192.168.1.1"
    #   #     prefix                    = 24
    #   #     dns_servers               = ["192.168.1.3", "8.8.4.4"]

    #   #     source_node   = "node03"
    #   #     template_id   = 103
    #   #     allowed_nodes = ["node03"]

    #   #     cp_replicas = 1
    #   #     wk_replicas = 2

    #   #     cp_disk_size = 20
    #   #     cp_memory    = 2048
    #   #     cp_cores     = 2
    #   #     wk_disk_size = 30
    #   #     wk_memory    = 4096
    #   #     wk_cores     = 2
    #   #   },
    #   # ]
    # }
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
