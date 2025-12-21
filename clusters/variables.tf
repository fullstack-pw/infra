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
      # "istio",
      # "argocd",
      # "teleport-agent",
      # "dev-postgres",
      # "observability-box"
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
      "observability-box",
      "teleport-agent",
      "proxmox-talos-cluster"
    ]
    tools = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "postgres",
      "redis",
      #"nats",
      "observability-box",
      #"gitlab_runner",
      "github_runner",
      "harbor",
      "minio",
      "terraform_state_backup",
      "vault",
      "teleport-agent",
      "clusterapi-operator"
    ]
    observability = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability"
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
      kubernetes_context   = "dev"
      install_crd          = false
      cert_manager_crd     = false
      argocd_ingress_class = "istio"
      argocd_domain        = "dev.argocd.fullstack.pw"
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
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
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
      prometheus_namespaces = [
        "cluster1",
        "cluster2",
        "cluster3",
        "kubevirt",
        "teleport-agent",
        "observability",
        "external-dns",
        "external-secrets",
        "kube-system",
        "cabpt-system",
        "cacppt-system",
        "capi-ipam-in-cluster-system",
        "capi-system",
        "capmox-system"
      ]
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
      proxmox-talos-cluster = [
        {
          name                      = "dev"
          kubernetes_version        = "v1.33.0"
          control_plane_endpoint_ip = "192.168.1.50"
          ip_range_start            = "192.168.1.51"
          ip_range_end              = "192.168.1.56"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3", "8.8.4.4"]

          source_node   = "node03"
          template_id   = 9005
          allowed_nodes = ["node03"]

          cp_replicas = 1
          wk_replicas = 2

          cp_disk_size = 20
          cp_memory    = 2048
          cp_cores     = 2
          wk_disk_size = 30
          wk_memory    = 4096
          wk_cores     = 4
        },
        #   {
        #   name                      = "stg"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.54"
        #   ip_range_start            = "192.168.1.55"
        #   ip_range_end              = "192.168.1.57"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 103
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 2

        #   cp_disk_size = 20
        #   cp_memory    = 2048
        #   cp_cores     = 2
        #   wk_disk_size = 30
        #   wk_memory    = 4096
        #   wk_cores     = 2
        #   }, {
        #   name                      = "prd"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.58"
        #   ip_range_start            = "192.168.1.59"
        #   ip_range_end              = "192.168.1.61"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 103
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 2

        #   cp_disk_size = 20
        #   cp_memory    = 2048
        #   cp_cores     = 2
        #   wk_disk_size = 30
        #   wk_memory    = 4096
        #   wk_cores     = 2
        # },
      ]
      #
      # proxmox-kubeadm-cluster = [
      #   {
      #     name                      = "dev"
      #     kubernetes_version        = "v1.31.4"
      #     control_plane_endpoint_ip = "192.168.1.70"
      #     ip_range_start            = "192.168.1.71"
      #     ip_range_end              = "192.168.1.79"
      #     gateway                   = "192.168.1.1"
      #     prefix                    = 24
      #     dns_servers               = ["192.168.1.3", "8.8.4.4"]
      #     pod_cidr                  = "10.244.0.0/16"
      #     service_cidr              = "10.96.0.0/12"

      #     cni_type         = "calico"
      #     cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"

      #     source_node   = "node03"
      #     template_id   = 9004
      #     allowed_nodes = ["node03"]

      #     cp_replicas  = 3
      #     cp_disk_size = 30
      #     cp_memory    = 4096
      #     cp_cores     = 2

      #     wk_replicas  = 1
      #     wk_disk_size = 30
      #     wk_memory    = 8192
      #     wk_cores     = 4
      #   },
      # ]
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
    }
    observability = {
      kubernetes_context = "k8s-observability"
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

