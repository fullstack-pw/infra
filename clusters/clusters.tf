variable "workload" {
  description = "map"
  type        = map(list(string))
  default = {
    clustermgmt = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability-box",
      "clusterapi-operator",
      "cluster-autoscaler",
    ]
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
      "falco",
      "kubevirt",
      "longhorn",
    ]
    observability = [
      "externaldns",
      "cert_manager",
      "external_secrets",
      "observability"
    ]
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
      "observability-box",
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
      "observability-box",
    ]
  }
}

variable "config" {
  description = "Map of providers with configuration per workspace."
  default = {
    clustermgmt = {
      kubernetes_context     = "clustermgmt"
      crds_installed         = true
      istio_CRDs             = false
      argocd_ingress_class   = "traefik"
      argocd_ingress_enabled = true
      argocd_domain          = "tools.argocd.homelabz.eu"
      teleport = {
        apps = {
          "harbor" = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"  = "http://vault.vault.svc.cluster.local:8200"
        }
        roles = "kube,app"
      }
      harbor = {
        harbor_domain      = "registry.toolz.homelabz.eu"
        ingress_class_name = "traefik"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "registry.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "2048Mi"
      prometheus_memory_request = "512Mi"
      redis = {
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"         = "redis.homelabz.eu"
          "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
          "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
          "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
          "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
          "nginx.ingress.kubernetes.io/service-upstream"      = "true"
        }
        ingress_host       = "redis.homelabz.eu"
        ingress_class_name = "traefik"
      }
      oracle_backup = {
        enable_s3_backup       = true
        enable_postgres_backup = true
        postgres_backups = {
          "postgres" = {
            namespace   = "oracle-backup"
            host        = "postgres.homelabz.eu"
            port        = 5432
            database    = "postgres"
            username    = "postgres"
            ssl_enabled = false
            schedule    = "0 3 * * *"
            backup_path = "postgres-backup/tools"
            secret_name = "cluster-secrets"   #pragma: allowlist secret
            secret_key  = "POSTGRES_PASSWORD" #pragma: allowlist secret
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
        domain   = "auth.homelabz.eu"
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
    toolz = {
      kubernetes_context  = "toolz"
      crds_installed      = true
      istio_CRDs          = false
      vault_addr          = "https://vault.toolz.homelabz.eu"
      vault_storage_class = "local-path"
      vault_ingress_annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = "vault.toolz.homelabz.eu"
        "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
      }
      minio = {
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "s3.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
        ingress_class_name = "nginx"
        ingress_host       = "s3.toolz.homelabz.eu"
        console_ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "minio.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
        console_ingress_class_name = "nginx"
        console_ingress_host       = "minio.toolz.homelabz.eu"
      }
      redis = {
        ingress_enabled    = false
        ingress_class_name = "nginx"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"         = "redis.toolz.homelabz.eu"
          "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
          "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
          "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
          "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
          "nginx.ingress.kubernetes.io/service-upstream"      = "true"
        }
        ingress_host = "redis.toolz.homelabz.eu"
        service_type = "LoadBalancer"
        service_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "redis.toolz.homelabz.eu"
        }
      }
      harbor = {
        harbor_domain           = "registry.toolz.homelabz.eu"
        ingress_class_name      = "nginx"
        registry_existing_claim = "harbor-registry-migration"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname"   = "registry.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          "nginx.org/client-max-body-size"              = "0"
        }
      }
      gitea = {
        domain              = "git.homelabz.eu"
        ssh_domain          = "git.homelabz.eu"
        ssh_port            = 2222
        ingress_class       = "traefik"
        url                 = "https://git.homelabz.eu"
        default_actions_url = "https://git.homelabz.eu"
      }
      github_runner = {
        registry_server = "registry.toolz.homelabz.eu"
      }
      vault_ingress_host       = "vault.toolz.homelabz.eu"
      argocd_ingress_class     = "nginx"
      argocd_ingress_enabled   = true
      argocd_domain            = "argocd.toolz.homelabz.eu"
      argocd_install_bootstrap = true
      teleport = {
        apps = {
          "harbor"   = "http://harbor-portal.harbor.svc.cluster.local"
          "vault"    = "http://vault.vault.svc.cluster.local:8200"
          "minio"    = "http://minio-console.default.svc.cluster.local:9001"
          "longhorn" = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
        }
        databases = {}
        roles     = "kube,app"
      }
      longhorn = {
        ingress_host       = "longhorn.toolz.homelabz.eu"
        ingress_class_name = "nginx"
        ingress_annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = "longhorn.toolz.homelabz.eu"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
      }
      kubevirt = {
        ingress_class_name    = "nginx"
        cdi_uploadproxy_host  = "cdi-uploadproxy.toolz.homelabz.eu"
        virt_exportproxy_host = "kubevirt-exportproxy.toolz.homelabz.eu"
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

      minio_memory_request = "128Mi"
      minio_cpu_request    = "50m"
      minio_memory_limit   = "256Mi"
      minio_cpu_limit      = "200m"

      prometheus_memory_request = "256Mi"
      prometheus_memory_limit   = "512Mi"
    }
    observability = {
      kubernetes_context = "k8s-observability"
      crds_installed     = true
    }
    home = {
      kubernetes_context = "home"
      crds_installed     = true
    }
    dev = {
      kubernetes_context     = "dev"
      crds_installed         = true
      istio_CRDs             = true
      argocd_ingress_class   = "istio"
      argocd_ingress_enabled = false
      argocd_domain          = "dev.argocd.homelabz.eu"
      gateway_dns_names = [
        "dev.api.cks.homelabz.eu",
        "dev.cks.homelabz.eu",
        "dev.argocd.homelabz.eu",
      ]
      teleport = {
        apps = {
          "dev-cks" = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        databases = {}
        roles     = "kube,app"
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.60-192.168.1.69"]
    }
    prod = {
      kubernetes_context     = "prod"
      crds_installed         = true
      istio_CRDs             = true
      argocd_ingress_class   = "istio"
      argocd_ingress_enabled = false
      argocd_domain          = "argocd.homelabz.eu"
      gateway_dns_names = [
        "api.cks.homelabz.eu",
        "cks.homelabz.eu",
        "argocd.homelabz.eu",
      ]
      teleport = {
        apps = {
          "cks" = "http://cks-frontend.default.svc.cluster.local:3000"
        }
        databases = {}
        roles     = "kube,app"
      }
      prometheus_namespaces     = []
      prometheus_memory_limit   = "1024Mi"
      prometheus_memory_request = "256Mi"
      prometheus_storage_size   = "2Gi"
      metallb_create_ip_pool    = true
      metallb_ip_pool_addresses = ["192.168.1.81-192.168.1.90"]
    }
  }
}
