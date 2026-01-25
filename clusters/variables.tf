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
    prod = [
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
      "oracle_backup"
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
      "vault",
      "argocd",
      "teleport-agent",
      "clusterapi-operator",
      "cloudnative-pg-operator",
      "postgres-cnpg",
      "oracle_backup",
      "cluster-autoscaler",
      #"authentik",
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
      crds_installed     = true
    }
    dev = {
      kubernetes_context   = "dev"
      crds_installed       = true
      istio_CRDs           = true
      argocd_ingress_class = "istio"
      argocd_domain        = "dev.argocd.fullstack.pw"
      gateway_dns_names = [
        "dev.ascii.fullstack.pw",
        "dev.enqueuer.fullstack.pw",
        "dev.memorizer.fullstack.pw",
        "dev.writer.fullstack.pw",
        "dev.api.cks.fullstack.pw",
        "dev.cks.fullstack.pw",
        "dev.argocd.fullstack.pw",
      ]
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
      metallb_ip_pool_addresses = ["192.168.1.60-192.168.1.69"]
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
        crds_installed          = true
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
    prod = {
      kubernetes_context   = "prod"
      crds_installed       = true
      istio_CRDs           = true
      argocd_ingress_class = "istio"
      argocd_domain        = "argocd.fullstack.pw"
      gateway_dns_names = [
        "ascii.fullstack.pw",
        "enqueuer.fullstack.pw",
        "memorizer.fullstack.pw",
        "writer.fullstack.pw",
        "api.cks.fullstack.pw",
        "cks.fullstack.pw",
        "argocd.fullstack.pw",
      ]
      teleport = {
        apps = {
          "ascii" = "http://ascii-frontend.default.svc.cluster.local"
          "cks"   = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        roles = "kube,app,db"
        databases = {
          "postgres" = {
            uri     = "postgres-rw.default.svc.cluster.local:5432"
            ca_cert = "POSTGRES_CA"
          }
        }
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.81-192.168.1.90"]
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
            backup_path = "postgres-backup/prod"
          }
        }
      }
      postgres_cnpg = {
        crds_installed          = true
        enable_superuser_access = true
        managed_roles = [
          { name = "root", login = true, replication = true }
        ]
        databases = []

        persistence_size               = "1Gi"
        ingress_host                   = "postgres.fullstack.pw"
        use_istio                      = true
        export_credentials_secret_name = "postgres-credentials"
        vault_ca_secret_path           = "cluster-secret-store/secrets/POSTGRES_CA"
        vault_ca_secret_key            = "POSTGRES_CA"
      }
    }
    sandboxy = {
      kubernetes_context = "sandboxy"
      crds_installed     = true
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
      kubernetes_context   = "tools"
      crds_installed       = true
      istio_CRDs           = false
      argocd_ingress_class = "traefik"
      argocd_domain        = "tools.argocd.fullstack.pw"
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
      # proxmox-cluster = [] # Migrated to kubernetes-cluster module
      # OLD - Moved to kubernetes-cluster array below
      # proxmox-cluster = [
      #   {
      #     name                      = "dev"
      #     kubernetes_version        = "v1.33.0"
      #     control_plane_endpoint_ip = "192.168.1.50"
      #     ip_range_start            = "192.168.1.51"
      #     ip_range_end              = "192.168.1.56"
      #     gateway                   = "192.168.1.1"
      #     prefix                    = 24
      #     dns_servers               = ["192.168.1.3", "8.8.4.4"]
      #
      #     source_node   = "node03"
      #     template_id   = 9005
      #     allowed_nodes = ["node03"]
      #
      #     cp_replicas = 1
      #     wk_replicas = 2
      #
      #     cp_disk_size = 20
      #     cp_memory    = 4096
      #     cp_cores     = 4
      #     wk_disk_size = 30
      #     wk_memory    = 8192
      #     wk_cores     = 8
      #
      #     autoscaler_enabled = true
      #     autoscaler_min     = 2
      #     autoscaler_max     = 4
      #   },
      #   {
      #     cluster_type              = "kubeadm"
      #     name                      = "prod"
      #     kubernetes_version        = "v1.31.4"
      #     control_plane_endpoint_ip = "192.168.1.70"
      #     ip_range_start            = "192.168.1.71"
      #     ip_range_end              = "192.168.1.79"
      #     gateway                   = "192.168.1.1"
      #     prefix                    = 24
      #     dns_servers               = ["192.168.1.3"]
      #
      #     source_node   = "node03"
      #     template_id   = 9004
      #     allowed_nodes = ["node03"]
      #
      #     cp_replicas = 1
      #     wk_replicas = 2
      #
      #     cp_disk_size           = 20
      #     cp_memory              = 4096
      #     cp_cores               = 4
      #     wk_disk_size           = 30
      #     wk_memory              = 8192
      #     wk_cores               = 8
      #     skip_cloud_init_status = false
      #     skip_qemu_guest_agent  = false
      #     provider_id_injection  = false
      #
      #     cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"
      #
      #     autoscaler_enabled = true
      #     autoscaler_min     = 2
      #     autoscaler_max     = 4
      #
      #   },
      # {
      #   cluster_type              = "rke2"
      #   name                      = "rke2-test"
      #   rke2_version              = "v1.33.1+rke2r1"
      #   kubernetes_version        = "v1.33.0"
      #   control_plane_endpoint_ip = "192.168.1.90"
      #   ip_range_start            = "192.168.1.91"
      #   ip_range_end              = "192.168.1.95"
      #   gateway                   = "192.168.1.1"
      #   prefix                    = 24
      #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

      #   source_node   = "node03"
      #   template_id   = 104
      #   allowed_nodes = ["node03"]

      #   cp_replicas = 1
      #   wk_replicas = 2

      #   cp_disk_size = 20
      #   cp_memory    = 4096
      #   cp_cores     = 4
      #   wk_disk_size = 30
      #   wk_memory    = 8192
      #   wk_cores     = 8

      #   rke2_cni                 = "cilium"
      #   rke2_registration_method = "internal-first"

      #   autoscaler_enabled = false
      # },
      # {
      #   cluster_type                = "k0s"
      #   name                        = "k0s"
      #   kubernetes_version          = "v1.32.6+k0s.0"
      #   control_plane_endpoint_host = "k0s-api.fullstack.pw" # DNS hostname for ingress
      #   control_plane_endpoint_ip   = "192.168.1.1"          # Not used for k0s, but required field
      #   ip_range_start              = "192.168.1.86"
      #   ip_range_end                = "192.168.1.89"
      #   gateway                     = "192.168.1.1"
      #   prefix                      = 24
      #   dns_servers                 = ["192.168.1.3", "8.8.4.4"]

      #   source_node   = "node03"
      #   template_id   = 104 # Ubuntu 24 template
      #   allowed_nodes = ["node03"]

      #   cp_replicas = 1 # Control plane pods (not VMs)
      #   wk_replicas = 1 # Worker VMs

      #   wk_disk_size = 30
      #   wk_memory    = 8192
      #   wk_cores     = 8

      #   cni_type     = "calico"
      #   pod_cidr     = "10.244.0.0/16"
      #   service_cidr = "10.96.0.0/12"
      # },
      # {
      #   cluster_type              = "k3s"
      #   name                      = "poc"
      #   k3s_version               = "v1.30.6+k3s1"
      #   control_plane_endpoint_ip = "192.168.1.90"
      #   ip_range_start            = "192.168.1.91"
      #   ip_range_end              = "192.168.1.99"
      #   gateway                   = "192.168.1.1"
      #   prefix                    = 24
      #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

      #   source_node   = "node03"
      #   template_id   = 104
      #   allowed_nodes = ["node03"]

      #   cp_replicas = 1
      #   wk_replicas = 0

      #   cp_disk_size = 30
      #   cp_memory    = 8192
      #   cp_cores     = 8
      #   wk_disk_size = 30
      #   wk_memory    = 4096
      #   wk_cores     = 4

      #   disable_cloud_controller = false
      #   #disable_components  = ["traefik", "servicelb", "metrics-server"]
      #   disable_components = []

      #   autoscaler_enabled = false
      # }
      # ]
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
      postgres_cnpg = {
        enable_superuser_access = true
        crds_installed          = true
        managed_roles = [
          { name = "teleport", login = true, replication = true },
          { name = "root", login = true, replication = true }

        ]
        databases = [
          { name = "registry", owner = "app" },
          { name = "teleport-backend", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "teleport-audit", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "authentik", owner = "app" },
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

      authentik = {
        domain   = "auth.fullstack.pw"
        redis_db = 1
      }

      kubernetes-cluster = [
        {
          cluster_type              = "talos"
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
          name                      = "prod"
          kubernetes_version        = "v1.31.4"
          control_plane_endpoint_ip = "192.168.1.70"
          ip_range_start            = "192.168.1.71"
          ip_range_end              = "192.168.1.79"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3"]

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

          autoscaler_enabled = true
          autoscaler_min     = 2
          autoscaler_max     = 4
        },
        # {
        #   cluster_type              = "talos"
        #   name                      = "test"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.80"
        #   ip_range_start            = "192.168.1.81"
        #   ip_range_end              = "192.168.1.85"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 9005
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 1

        #   cp_disk_size = 20
        #   cp_memory    = 4096
        #   cp_cores     = 4
        #   wk_disk_size = 20
        #   wk_memory    = 4096
        #   wk_cores     = 4

        #   autoscaler_enabled = false
        # },
        # {
        #   cluster_type              = "kubeadm"
        #   name                      = "kubeadm-test"
        #   kubernetes_version        = "v1.31.4"
        #   control_plane_endpoint_ip = "192.168.1.100"
        #   ip_range_start            = "192.168.1.101"
        #   ip_range_end              = "192.168.1.105"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3"]

        #   source_node   = "node03"
        #   template_id   = 9004
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 1

        #   cp_disk_size           = 20
        #   cp_memory              = 4096
        #   cp_cores               = 4
        #   wk_disk_size           = 20
        #   wk_memory              = 4096
        #   wk_cores               = 4
        #   skip_cloud_init_status = false
        #   skip_qemu_guest_agent  = false
        #   provider_id_injection  = false

        #   cni_manifest_url = "https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml"

        #   autoscaler_enabled = false
        # },
        {
          cluster_type              = "k3s"
          name                      = "k3s-test"
          k3s_version               = "v1.30.6+k3s1"
          control_plane_endpoint_ip = "192.168.1.110"
          ip_range_start            = "192.168.1.111"
          ip_range_end              = "192.168.1.115"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3"]

          source_node   = "node03"
          template_id   = 9004
          allowed_nodes = ["node03"]

          cp_replicas = 1
          wk_replicas = 1

          cp_disk_size = 20
          cp_memory    = 4096
          cp_cores     = 4
          wk_disk_size = 20
          wk_memory    = 4096
          wk_cores     = 4

          disable_components = ["traefik", "servicelb"]
          autoscaler_enabled = false
        }
      ]
    }
    observability = {
      kubernetes_context = "k8s-observability"
      crds_installed     = true
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

