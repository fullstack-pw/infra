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
      "local-path-provisioner",
      "metrics-server",
      "metallb",
      "externaldns",
      "cert_manager",
      "external_secrets",
      "istio",
      "argocd",
      "teleport-agent",
      "cloudnative-pg-operator",
      "postgres-cnpg",
      "observability-box",
      "oracle_backup",
      #"freqtrade"
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
      "teleport-agent"
    ]
    tools = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "redis",
      "nats",
      "observability-box",
      #"gitlab_runner",
      "github_runner",
      "harbor",
      "minio",
      #"terraform_state_backup",
      "vault",
      "teleport-agent",
      "clusterapi-operator",
      "cloudnative-pg-operator",
      "postgres-cnpg",
      "oracle_backup",
      "cluster-autoscaler",
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
      install_crd          = true
      cert_manager_crd     = true
      istio_CRDs           = true
      argocd_ingress_class = "istio"
      argocd_domain        = "dev.argocd.fullstack.pw"
      teleport = {
        apps = {
          "dev-ascii" = "http://ascii-frontend.default.svc.cluster.local"
          "dev-cks"   = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        roles = "kube,app,db"
        databases = {
          "dev-postgres" = {
            uri     = "postgres-rw.default.svc.cluster.local:5432"
            ca_cert = "DEV_POSTGRES_CA"
          }
        }
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.70-192.168.1.80"]
      freqtrade = {
        domain          = "freqtrade.dev.fullstack.pw"
        dry_run         = true
        stake_amount    = 50
        max_open_trades = 5
        freqai          = true
      }
      oracle_backup = {
        enable_s3_backup       = false
        enable_postgres_backup = true

        postgres_backups = {
          "postgres" = {
            namespace   = "default"
            host        = "postgres-rw.default.svc.cluster.local"
            port        = 5432
            database    = "postgres"
            username    = "postgres"
            ssl_enabled = false
            schedule    = "0 4 * * *"
            backup_path = "postgres-backup/dev"
          }
        }
      }
      postgres_cnpg = {
        enable_superuser_access = true
        managed_roles = [
          { name = "root", login = true, replication = true }
        ]
        databases = []

        persistence_size               = "1Gi"
        ingress_host                   = "dev.postgres.fullstack.pw"
        use_istio                      = true
        export_credentials_secret_name = "dev-postgres-credentials"
        vault_ca_secret_path           = "cluster-secret-store/secrets/DEV_POSTGRES_CA"
        vault_ca_secret_key            = "DEV_POSTGRES_CA"
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
        databases = {
          "tools-postgres" = {
            uri     = "postgres-rw.default.svc.cluster.local:5432"
            ca_cert = "TOOLS_POSTGRES_CA"
          }
        }
        roles = "kube,app,db"
      }
      proxmox-cluster = [
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
          cp_memory    = 4096
          cp_cores     = 4
          wk_disk_size = 30
          wk_memory    = 8192
          wk_cores     = 8

          autoscaler_enabled = true
          autoscaler_min     = 2
          autoscaler_max     = 4
        },
        {
          cluster_type              = "kubeadm"
          name                      = "stg"
          kubernetes_version        = "v1.31.4"
          control_plane_endpoint_ip = "192.168.1.70"
          ip_range_start            = "192.168.1.71"
          ip_range_end              = "192.168.1.79"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3", "8.8.4.4"]

          source_node   = "node03"
          template_id   = 9004
          allowed_nodes = ["node03"]

          cp_replicas = 1
          wk_replicas = 2

          cp_disk_size           = 20
          cp_memory              = 4096
          cp_cores               = 4
          wk_disk_size           = 30
          wk_memory              = 8192
          wk_cores               = 8
          skip_cloud_init_status = false
          skip_qemu_guest_agent  = false
          provider_id_injection  = false

          cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"

        },
        #   {
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
      #     name                      = "stg"
      #     kubernetes_version        = "v1.31.4"
      #     control_plane_endpoint_ip = "192.168.1.60"
      #     ip_range_start            = "192.168.1.61"
      #     ip_range_end              = "192.168.1.69"
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

      #     cp_replicas  = 1
      #     cp_disk_size = 30
      #     cp_memory    = 4096
      #     cp_cores     = 4

      #     wk_replicas  = 2
      #     wk_disk_size = 30
      #     wk_memory    = 8192
      #     wk_cores     = 8
      #   },
      # ]
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
      postgres_cnpg = {
        enable_superuser_access = true
        managed_roles = [
          { name = "teleport", login = true, replication = true },
          { name = "root", login = true, replication = true }

        ]
        databases = [
          { name = "registry", owner = "app" },
          { name = "teleport-backend", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "teleport-audit", owner = "app", locale_collate = "C", locale_ctype = "C" },
        ]

        persistence_size               = "10Gi"
        ingress_host                   = "tools.postgres.fullstack.pw"
        ingress_class_name             = "traefik"
        use_istio                      = false
        export_credentials_secret_name = "tools-postgres-credentials"
        vault_ca_secret_path           = "cluster-secret-store/secrets/TOOLS_POSTGRES_CA"
        vault_ca_secret_key            = "TOOLS_POSTGRES_CA"
      }

      oracle_backup = {
        enable_s3_backup       = true
        enable_postgres_backup = true
        postgres_backups = {
          "postgres" = {
            namespace   = "default"
            host        = "postgres-rw.default.svc.cluster.local"
            port        = 5432
            database    = "postgres"
            username    = "postgres"
            ssl_enabled = false
            schedule    = "0 3 * * *"
            backup_path = "postgres-backup/tools"
          }
        }
      }

      cluster_autoscaler_managed_clusters = [
        {
          name      = "dev"
          namespace = "dev"
        }
      ]
      cluster_autoscaler_chart_version      = "9.54.0"
      cluster_autoscaler_image_tag          = "v1.34.2"
      cluster_autoscaler_scale_down_enabled = true
      cluster_autoscaler_scale_down_delay   = "10m"
      cluster_autoscaler_unneeded_time      = "10m"
      cluster_autoscaler_replicas           = 1
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

