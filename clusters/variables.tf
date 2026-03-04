variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    toolz = [
      "local-path-provisioner",
      "metallb",
      "externaldns",
      "cert_manager",
      "external_secrets",
      "redis",
      "nats",
      "observability-box",
      # "gitea",
      # "gitea_runner",
      "github_runner",
      "harbor",
      "minio",
      "vault",
      "argocd",
      "teleport-agent",
      "cloudnative-pg-operator",
      "postgres-cnpg",
      "oracle_backup",
      "falco",
      "kubevirt",
      "longhorn",
    ]
    home = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "immich"
    ]
    k3s-test = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "cloudnative-pg-operator",
      "postgres-cnpg",
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
      "teleport-agent",
      "argocd",
    ]
    clustermgmt = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "clusterapi-operator",
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
    toolz = {
      kubernetes_context  = "toolz"
      crds_installed      = true
      istio_CRDs          = false
      vault_addr          = "https://vault.toolz.fullstack.pw"
      vault_storage_class = "local-path"
      vault_ingress_annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = "vault.toolz.fullstack.pw"
        "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
      }
      minio = {
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "s3.toolz.fullstack.pw"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
        ingress_class_name = "nginx"
        ingress_host       = "s3.toolz.fullstack.pw"
        console_ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "minio.toolz.fullstack.pw"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
        console_ingress_class_name = "nginx"
        console_ingress_host       = "minio.toolz.fullstack.pw"
      }
      redis = {
        ingress_enabled    = false
        ingress_class_name = "nginx"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"         = "redis.toolz.fullstack.pw"
          "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
          "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
          "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
          "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
          "nginx.ingress.kubernetes.io/service-upstream"      = "true"
        }
        ingress_host = "redis.toolz.fullstack.pw"
        service_type = "LoadBalancer"
        service_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "redis.toolz.fullstack.pw"
        }
      }
      harbor = {
        harbor_domain           = "registry.toolz.fullstack.pw"
        ingress_class_name      = "nginx"
        registry_existing_claim = "harbor-registry-migration"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "registry.toolz.fullstack.pw"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
      }
      gitea = {
        domain              = "git.fullstack.pw"
        ssh_domain          = "git.fullstack.pw"
        ssh_port            = 2222
        ingress_class       = "traefik"
        url                 = "https://git.fullstack.pw"
        default_actions_url = "https://git.fullstack.pw"
      }
      github_runner = {
        registry_server = "registry.toolz.fullstack.pw"
      }
      vault_ingress_host       = "vault.toolz.fullstack.pw"
      argocd_ingress_class     = "nginx"
      argocd_ingress_enabled   = true
      argocd_domain            = "argocd.toolz.fullstack.pw"
      argocd_install_bootstrap = true
      teleport = {
        apps = {
          "harbor"   = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"    = "http://vault.vault.svc.cluster.local:8200"
          "minio"    = "http://minio-console.default.svc.cluster.local:9001"
          "longhorn" = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
        }
        databases = {
          "toolz-postgres" = {
            uri     = "postgres-rw.default.svc.cluster.local:5432"
            ca_cert = "TOOLZ_POSTGRES_CA"
          }
        }
        roles = "kube,app,db"
      }
      longhorn = {
        ingress_host       = "longhorn.toolz.fullstack.pw"
        ingress_class_name = "nginx"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "longhorn.toolz.fullstack.pw"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
      }
      kubevirt = {
        ingress_class_name    = "nginx"
        cdi_uploadproxy_host  = "cdi-uploadproxy.toolz.fullstack.pw"
        virt_exportproxy_host = "kubevirt-exportproxy.toolz.fullstack.pw"
      }
      prometheus_namespaces = [
        # "cluster1",
        # "cluster2",
        # "cluster3",
        "kubevirt",
        "teleport-agent",
        "observability",
        "external-dns",
        "external-secrets",
        "kube-system",
        # "cabpt-system",
        # "cacppt-system",
        # "capi-ipam-in-cluster-system",
        # "capi-system",
        # "capmox-system"
      ]
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.40-192.168.1.49"]

      vault_memory_request = "300Mi"
      vault_cpu_request    = "100m"
      vault_memory_limit   = "600Mi"
      vault_cpu_limit      = "300m"

      redis_memory_request = "64Mi"
      redis_cpu_request    = "50m"
      redis_memory_limit   = "128Mi"
      redis_cpu_limit      = "200m"

      postgres_memory_request = "512Mi"
      postgres_cpu_request    = "250m"
      postgres_memory_limit   = "1Gi"
      postgres_cpu_limit      = "500m"

      minio_memory_request = "128Mi"
      minio_cpu_request    = "50m"
      minio_memory_limit   = "256Mi"
      minio_cpu_limit      = "200m"

      prometheus_memory_request = "256Mi"
      prometheus_memory_limit   = "512Mi"
      postgres_cnpg = {
        enable_superuser_access = true
        crds_installed          = true
        managed_roles = [
          { name = "teleport", login = true, replication = true, password_secret_name = "teleport-postgres-password" }, # pragma: allowlist secret
          { name = "root", login = true, replication = true }
        ]
        databases = [
          { name = "registry", owner = "app" },
          { name = "teleport-backend", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "teleport-audit", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "immich", owner = "app" },
        ]

        persistence_size               = "10Gi"
        ingress_enabled                = false
        ingress_host                   = "postgres.toolz.fullstack.pw"
        ingress_class_name             = "nginx"
        use_istio                      = false
        create_lb_service              = true
        generate_password              = false
        export_credentials_secret_name = "toolz-postgres-credentials"                     # pragma: allowlist secret
        vault_ca_secret_path           = "cluster-secret-store/secrets/TOOLZ_POSTGRES_CA" # pragma: allowlist secret
        vault_ca_secret_key            = "TOOLZ_POSTGRES_CA"                              # pragma: allowlist secret
      }

      oracle_backup = {
        enable_s3_backup       = false
        enable_postgres_backup = false
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
    }
    home = {
      kubernetes_context = "home"
      crds_installed     = true
    }
    k3s-test = {
      kubernetes_context = "k3s-test"
      crds_installed     = true
      postgres_cnpg = {
        enable_superuser_access = true
        crds_installed          = true
        managed_roles = [
          { name = "root", login = true, replication = true }
        ]
        databases = []

        persistence_size               = "1Gi"
        ingress_host                   = "test.postgres.fullstack.pw"
        use_istio                      = true
        export_credentials_secret_name = "test-postgres-credentials"                     # pragma: allowlist secret
        vault_ca_secret_path           = "cluster-secret-store/secrets/TEST_POSTGRES_CA" # pragma: allowlist secret
        vault_ca_secret_key            = "TEST_POSTGRES_CA"                              # pragma: allowlist secret
      }
    }
    dev = {
      kubernetes_context     = "dev"
      crds_installed         = true
      istio_CRDs             = true
      argocd_ingress_class   = "istio"
      argocd_ingress_enabled = false
      argocd_domain          = "dev.argocd.fullstack.pw"
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
        export_credentials_secret_name = "dev-postgres-credentials"                     # pragma: allowlist secret
        vault_ca_secret_path           = "cluster-secret-store/secrets/DEV_POSTGRES_CA" # pragma: allowlist secret
        vault_ca_secret_key            = "DEV_POSTGRES_CA"                              # pragma: allowlist secret
      }
    }
    prod = {
      kubernetes_context     = "prod"
      crds_installed         = true
      istio_CRDs             = true
      argocd_ingress_class   = "istio"
      argocd_ingress_enabled = false
      argocd_domain          = "argocd.fullstack.pw"
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
        export_credentials_secret_name = "postgres-credentials"                     # pragma: allowlist secret
        vault_ca_secret_path           = "cluster-secret-store/secrets/POSTGRES_CA" # pragma: allowlist secret
        vault_ca_secret_key            = "POSTGRES_CA"                              # pragma: allowlist secret
      }
    }
    sandboxy = {
      kubernetes_context     = "sandboxy"
      crds_installed         = true
      istio_CRDs             = false
      argocd_ingress_class   = "traefik"
      argocd_ingress_enabled = false
      argocd_domain          = "sandboxy.argocd.fullstack.pw"
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
    clustermgmt = {
      kubernetes_context     = "clustermgmt"
      crds_installed         = true
      istio_CRDs             = false
      argocd_ingress_class   = "traefik"
      argocd_ingress_enabled = true
      argocd_domain          = "tools.argocd.fullstack.pw"
      teleport = {
        apps = {
          "harbor" = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"  = "http://vault.vault.svc.cluster.local:8200"
        }
        databases = {
          "tools-postgres" = {
            uri     = "postgres-rw.default.svc.cluster.local:5432"
            ca_cert = "TOOLS_POSTGRES_CA"
          }
        }
        roles = "kube,app,db"
      }
      harbor = {
        harbor_domain      = "registry.fullstack.pw"
        ingress_class_name = "traefik"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "registry.fullstack.pw"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
      postgres_cnpg = {
        enable_superuser_access = true
        crds_installed          = true
        managed_roles = [
          { name = "teleport", login = true, replication = true, password_secret_name = "teleport-postgres-password" }, # pragma: allowlist secret
          { name = "root", login = true, replication = true }

        ]
        databases = [
          { name = "registry", owner = "app" },
          { name = "teleport-backend", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "teleport-audit", owner = "app", locale_collate = "C", locale_ctype = "C" },
          { name = "authentik", owner = "app" },
          { name = "gitea", owner = "app" },
        ]

        persistence_size               = "10Gi"
        ingress_host                   = "tools.postgres.fullstack.pw"
        ingress_class_name             = "traefik"
        use_istio                      = false
        export_credentials_secret_name = "tools-postgres-credentials"                     # pragma: allowlist secret
        vault_ca_secret_path           = "cluster-secret-store/secrets/TOOLS_POSTGRES_CA" # pragma: allowlist secret
        vault_ca_secret_key            = "TOOLS_POSTGRES_CA"                              # pragma: allowlist secret
      }
      redis = {
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"         = "redis.fullstack.pw"
          "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
          "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
          "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
          "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
          "nginx.ingress.kubernetes.io/service-upstream"      = "true"
        }
        ingress_host       = "redis.fullstack.pw"
        ingress_class_name = "traefik"
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
          name      = "toolz"
          namespace = "toolz"
        }
      ]
      cluster_autoscaler_chart_version      = "9.54.0"
      cluster_autoscaler_image_tag          = "v1.34.2"
      cluster_autoscaler_scale_down_enabled = false
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
        {
          cluster_type              = "rke2"
          name                      = "toolz"
          kubernetes_version        = "v1.33.0"
          rke2_version              = "v1.33.1+rke2r1"
          control_plane_endpoint_ip = "192.168.1.30"
          ip_range_start            = "192.168.1.31"
          ip_range_end              = "192.168.1.39"
          gateway                   = "192.168.1.1"
          prefix                    = 24
          dns_servers               = ["192.168.1.3", "8.8.4.4"]

          source_node        = "node03"
          template_id        = 9006
          allowed_nodes      = ["node03"]
          kube_vip_interface = "ens18"

          cp_replicas = 1
          wk_replicas = 1

          cp_disk_size = 50
          cp_memory    = 8192
          cp_cores     = 8
          wk_disk_size = 100
          wk_memory    = 16384
          wk_cores     = 8

          autoscaler_enabled = true
          autoscaler_min     = 1
          autoscaler_max     = 5
        },
        # {
        #   cluster_type              = "talos"
        #   name                      = "test"
        #   kubernetes_version        = "v1.33.0"
        #   control_plane_endpoint_ip = "192.168.1.60"
        #   ip_range_start            = "192.168.1.61"
        #   ip_range_end              = "192.168.1.66"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3", "8.8.4.4"]

        #   source_node   = "node03"
        #   template_id   = 9005
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 0

        #   cp_disk_size = 20
        #   cp_memory    = 8192
        #   cp_cores     = 8
        #   wk_disk_size = 30
        #   wk_memory    = 8192
        #   wk_cores     = 8
        # },
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
        # {
        #   cluster_type              = "k3s"
        #   name                      = "k3s-test"
        #   k3s_version               = "v1.30.6+k3s1"
        #   control_plane_endpoint_ip = "192.168.1.110"
        #   ip_range_start            = "192.168.1.111"
        #   ip_range_end              = "192.168.1.115"
        #   gateway                   = "192.168.1.1"
        #   prefix                    = 24
        #   dns_servers               = ["192.168.1.3"]

        #   source_node   = "node03"
        #   template_id   = 9004
        #   allowed_nodes = ["node03"]

        #   cp_replicas = 1
        #   wk_replicas = 0

        #   cp_disk_size = 20
        #   cp_memory    = 8192
        #   cp_cores     = 8
        #   wk_disk_size = 20
        #   wk_memory    = 4096
        #   wk_cores     = 4

        #   disable_components = []
        #   autoscaler_enabled = false
        # }
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
  default = "https://vault.toolz.fullstack.pw"
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
