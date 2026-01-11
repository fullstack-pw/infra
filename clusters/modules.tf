module "local_path_provisioner" {
  count  = contains(local.workload, "local-path-provisioner") ? 1 : 0
  source = "../modules/apps/local-path-provisioner"

  namespace                 = "local-path-storage"
  storage_class_name        = "local-path"
  set_default_storage_class = true
}

module "metrics_server" {
  count  = contains(local.workload, "metrics-server") ? 1 : 0
  source = "../modules/apps/metrics-server"

  namespace              = "kube-system"
  enable_service_monitor = contains(local.workload, "observability-box")
}

module "metallb" {
  count  = contains(local.workload, "metallb") ? 1 : 0
  source = "../modules/apps/metallb"

  namespace      = "metallb-system"
  chart_version  = "0.14.9"
  create_ip_pool = var.config[terraform.workspace].metallb_create_ip_pool
  ip_pool_name   = "default-pool"
  ip_pool_addresses = lookup(
    var.config[terraform.workspace],
    "metallb_ip_pool_addresses",
    []
  )
  l2_advertisement_name = "default-l2"
}

module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  deployment_name      = "external-dns-pihole"
  dns_provider         = "pihole"
  create_pihole_secret = terraform.workspace == "sandbox" ? true : false
  pihole_password      = terraform.workspace == "sandbox" ? local.secrets_json["kv/cluster-secret-store/secrets/EXTERNAL_DNS_PIHOLE_PASSWORD"]["PIHOLE_PASSWORD"] : ""

  container_args = contains(local.workload, "istio") ? [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--source=istio-gateway",
    "--source=istio-virtualservice",
    "--registry=noop",
    "--policy=upsert-only",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3",
    ] : [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--registry=noop",
    "--policy=upsert-only",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3",
  ]
}

module "externaldns_cloudflare" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  deployment_name          = "external-dns-cloudflare"
  dns_provider             = "cloudflare"
  create_cloudflare_secret = true
  cloudflare_api_token     = local.secrets_json["kv/cloudflare"]["api-token"]
  container_args = !contains(local.workload, "istio") ? [
    "--source=ingress",
    "--registry=txt",
    "--txt-owner-id=k8s-${terraform.workspace}",
    "--policy=sync",
    "--provider=cloudflare",
    ] : [
    "--source=ingress",
    "--source=istio-gateway",
    "--source=istio-virtualservice",
    "--registry=txt",
    "--txt-owner-id=k8s-${terraform.workspace}",
    "--policy=sync",
    "--provider=cloudflare",
  ]
  create_namespace = false
}

moved {
  from = module.externaldns[0].module.namespace.kubernetes_namespace.this[0]
  to   = module.externaldns[0].module.namespace[0].kubernetes_namespace.this[0]
}
module "cert_manager" {
  count  = contains(local.workload, "cert_manager") ? 1 : 0
  source = "../modules/apps/certmanager"

  install_crd       = var.config[terraform.workspace].cert_manager_crd
  cloudflare_secret = local.secrets_json["kv/cloudflare"]["api-token"]
}

module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/apps/external-secrets"

  install_crd = var.config[terraform.workspace].install_crd
  secret_data = local.secret_data
  vault_token = local.secrets_json["kv/cluster-secret-store/secrets/VAULT_TOKEN"]["VAULT_TOKEN"]

  namespace_selector_type = "label"
  namespace_selector_label = {
    key   = "cluster-secrets"
    value = "true"
  }
}


module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/apps/github-runner"

  github_token = local.secrets_json["kv/cluster-secret-store/secrets/github_token"]["github_token"]
  install_crd  = var.config[terraform.workspace].install_crd
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/apps/gitlab-runner"

  gitlab_token = local.secrets_json["kv/cluster-secret-store/secrets/GITLAB_TOKEN"]["GITLAB_TOKEN"]
}

module "ingress_nginx" {
  count  = contains(local.workload, "ingress_nginx") ? 1 : 0
  source = "../modules/apps/ingress-nginx"

}

module "istio" {
  count  = contains(local.workload, "istio") ? 1 : 0
  source = "../modules/apps/istio"

  gateway_service_type = "LoadBalancer"

  pilot_replicas   = 1
  gateway_replicas = 1

  enable_telemetry = true
  enable_tracing   = false # Can be enabled later to integrate with Jaeger
  access_log_file  = "/dev/stdout"

  istio_CRDs         = true
  default_tls_secret = "default-gateway-tls"

  cert_issuer_name = "letsencrypt-prod"
  cert_issuer_kind = "ClusterIssuer"
  gateway_dns_names = [
    "*.ascii.fullstack.pw",
    "*.enqueuer.fullstack.pw",
    "*.api.cks.fullstack.pw",
    "*.cks.fullstack.pw",
    "*.argocd.fullstack.pw",
  ]
}

module "argocd" {
  count  = contains(local.workload, "argocd") ? 1 : 0
  source = "../modules/apps/argocd"

  namespace              = "argocd"
  argocd_version         = "7.7.12"
  argocd_domain          = var.config[terraform.workspace].argocd_domain
  ingress_enabled        = true
  ingress_class_name     = var.config[terraform.workspace].argocd_ingress_class
  cert_issuer            = "letsencrypt-prod"
  use_istio              = contains(local.workload, "istio")
  admin_password_bcrypt  = local.secrets_json["kv/cluster-secret-store/secrets/ARGOCD"]["ADMIN_PASSWORD_BCRYPT"]
  application_namespaces = "*"
  enable_notifications   = true
  enable_dex             = false
  istio_CRDs             = true
}

module "minio" {
  count  = contains(local.workload, "minio") ? 1 : 0
  source = "../modules/apps/minio"

  root_password = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
}

module "terraform_state_backup" {
  count  = contains(local.workload, "terraform_state_backup") ? 1 : 0
  source = "../modules/apps/terraform-state-backup"

  name      = "terraform-state-backup"
  namespace = "default"

  # Backup schedule - daily at 2 AM UTC
  schedule = "0 2 * * *"

  # MinIO configuration
  minio_endpoint    = "https://s3.fullstack.pw"
  minio_access_key  = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootUser"]
  minio_secret_key  = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
  minio_region      = "main"
  minio_bucket_path = "terraform" # Backs up the entire terraform bucket

  # Oracle Cloud OCI CLI configuration
  oracle_user_ocid    = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["userOcid"]
  oracle_tenancy_ocid = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["tenancyOcid"]
  oracle_fingerprint  = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["fingerprint"]
  oracle_private_key  = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["privateKey"]
  oracle_region       = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["region"]
  oracle_namespace    = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["namespace"]
  oracle_bucket       = local.secrets_json["kv/cluster-secret-store/secrets/ORACLE_CLOUD"]["bucket"]
  backup_path         = "terraform-state-backup"

  # Resource limits - increased for tool installation
  memory_request = "256Mi"
  memory_limit   = "1Gi"
  cpu_request    = "200m"
  cpu_limit      = "1000m"

  depends_on = [module.minio]
}

module "oracle_backup" {
  count  = contains(keys(var.config[terraform.workspace]), "oracle_backup") ? 1 : 0
  source = "../modules/apps/oracle-backup"

  namespace        = "oracle-backup"
  create_namespace = true

  enable_s3_backup       = try(var.config[terraform.workspace].oracle_backup.enable_s3_backup, false)
  enable_postgres_backup = try(var.config[terraform.workspace].oracle_backup.enable_postgres_backup, false)

  s3_backup_name    = "terraform-state-backup"
  s3_schedule       = "0 2 * * *"
  minio_endpoint    = "https://s3.fullstack.pw"
  minio_bucket_path = "terraform"
  s3_backup_path    = "terraform-state-backup"

  postgres_backups = {
    for key, config in try(var.config[terraform.workspace].oracle_backup.postgres_backups, {}) : key => {
      namespace      = config.namespace
      host           = config.host
      port           = config.port
      database       = config.database
      username       = config.username
      ssl_enabled    = config.ssl_enabled
      schedule       = config.schedule
      backup_path    = config.backup_path
      databases      = try(config.databases, [])
      memory_request = try(config.memory_request, "256Mi")
      memory_limit   = try(config.memory_limit, "1Gi")
      cpu_request    = try(config.cpu_request, "200m")
      cpu_limit      = try(config.cpu_limit, "1000m")
    }
  }

  memory_request = "256Mi"
  memory_limit   = "1Gi"
  cpu_request    = "200m"
  cpu_limit      = "1000m"

  depends_on = [module.minio, module.external_secrets]
}

module "registry" {
  count  = contains(local.workload, "registry") ? 1 : 0
  source = "../modules/apps/registry"

}

module "vault" {
  count           = contains(local.workload, "vault") ? 1 : 0
  source          = "../modules/apps/vault"
  initial_secrets = local.vault_secrets
}

module "observability" {
  count  = contains(local.workload, "observability") ? 1 : 0
  source = "../modules/apps/observability"

  minio_rootPassword = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
  install_crd        = var.config[terraform.workspace].install_crd
}

module "observability-box" {
  count  = contains(local.workload, "observability-box") ? 1 : 0
  source = "../modules/apps/observability-box"

  prometheus_namespaces     = try(var.config[terraform.workspace].prometheus_namespaces, [])
  prometheus_memory_limit   = try(var.config[terraform.workspace].prometheus_memory_limit, "1024Mi")
  prometheus_memory_request = try(var.config[terraform.workspace].prometheus_memory_request, "256Mi")
  prometheus_storage_size   = try(var.config[terraform.workspace].prometheus_storage_size, "")
}

module "redis" {
  count  = contains(local.workload, "redis") ? 1 : 0
  source = "../modules/apps/redis"

}


module "nats" {
  count  = contains(local.workload, "nats") ? 1 : 0
  source = "../modules/apps/nats"

}

module "harbor" {
  count  = contains(local.workload, "harbor") ? 1 : 0
  source = "../modules/apps/harbor"

  external_database_host     = "postgres-rw.default.svc.cluster.local"
  external_database_password = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  external_redis_password    = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
  #ingress_annotations        = var.config[terraform.workspace].harbor.ingress
  ingress_enabled = true
}

module "immich" {
  count  = contains(local.workload, "immich") ? 1 : 0
  source = "../modules/apps/immich"

  redis         = "redis.fullstack.pw"
  redis_pass    = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
  db_hostname   = "tools.postgres.fullstack.pw"
  db_user       = "admin"
  db_name       = "immich"
  db_pass       = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  immich_domain = "immich.fullstack.pw"

}

module "kubevirt_operator" {
  count  = contains(local.workload, "kubevirt") ? 1 : 0
  source = "../modules/apps/kubevirt-operator"

}

module "kubevirt" {
  count  = contains(local.workload, "kubevirt") ? 1 : 0
  source = "../modules/apps/kubevirt"

  namespace          = "kubevirt"
  create_kubevirt_cr = true
  create_cdi_cr      = true

  kubevirt_feature_gates = ["Snapshot", "VMExport"]
  cdi_feature_gates      = ["HonorWaitForFirstConsumer"]

  enable_cdi_uploadproxy_ingress = true
  cdi_uploadproxy_host           = "cdi-uploadproxy.fullstack.pw"

  depends_on = [module.kubevirt_operator]
}

module "longhorn" {
  count  = contains(local.workload, "longhorn") ? 1 : 0
  source = "../modules/apps/longhorn"

  replica_count = 1
  ingress_host  = "longhorn.fullstack.pw"
}

module "clusterapi_operator" {
  count  = contains(local.workload, "clusterapi-operator") ? 1 : 0
  source = "../modules/apps/clusterapi-operator"

  enable_core_provider    = true
  enable_talos_provider   = true
  enable_k3s_provider     = false
  enable_kubeadm_provider = true

  # Downgrade to CAPI v1.9 for compatibility with CAPMOX v0.7.x
  # core_provider_version        = "v1.9.4"
  # kubeadm_bootstrap_version    = "v1.9.4"
  # kubeadm_controlplane_version = "v1.9.4"

  proxmox_secret_name = "proxmox-credentials"
  proxmox_url         = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret      = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token       = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]

  depends_on = [module.vault]
}

module "proxmox_clusters" {
  count  = contains(keys(var.config[terraform.workspace]), "proxmox-cluster") ? 1 : 0
  source = "../modules/apps/proxmox-cluster"

  clusters = var.config[terraform.workspace].proxmox-cluster

  cluster_api_dependencies = []

  create_proxmox_secret = true
  proxmox_url           = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret        = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token         = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]
  ssh_authorized_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"
  ]
}

data "vault_kv_secret_v2" "postgres_ca" {
  for_each = local.postgres_ca_secrets
  mount    = "kv"
  name     = "cluster-secret-store/secrets/${each.key}"
}

module "teleport-agent" {
  count  = contains(local.workload, "teleport-agent") ? 1 : 0
  source = "../modules/apps/teleport-agent"

  kubernetes_cluster_name = terraform.workspace
  join_token              = local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT"]["JOIN_TOKEN"]
  ca_pin                  = local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT"]["CA_PIN"]
  roles                   = var.config[terraform.workspace].teleport.roles
  apps                    = var.config[terraform.workspace].teleport.apps
  databases = {
    for name, db in var.config[terraform.workspace].teleport.databases : name => {
      uri = db.uri
      ca_cert = db.ca_cert != "" ? (
        contains(keys(data.vault_kv_secret_v2.postgres_ca), db.ca_cert) ?
        data.vault_kv_secret_v2.postgres_ca[db.ca_cert].data[db.ca_cert] :
        try(local.secrets_json["kv/cluster-secret-store/secrets/${db.ca_cert}"][db.ca_cert], "")
      ) : ""
    }
  }
}

module "cloudnative_pg_operator" {
  count  = contains(local.workload, "cloudnative-pg-operator") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres-operator"

  namespace        = "cnpg-system"
  create_namespace = true
  chart_version    = "0.27.0"
}

module "postgres_cnpg" {
  count  = contains(local.workload, "postgres-cnpg") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres"

  cluster_name     = "postgres"
  namespace        = "default"
  create_namespace = false
  create_cluster   = true

  registry   = "registry.fullstack.pw"
  repository = "library/postgresql"
  pg_version = "15-wal2json"

  postgres_generate_password = true
  postgres_password          = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]

  persistence_size = try(var.config[terraform.workspace].postgres_cnpg.persistence_size, "10Gi")
  storage_class    = ""

  memory_request = "512Mi"
  cpu_request    = "250m"
  memory_limit   = "1Gi"
  cpu_limit      = "500m"

  enable_ssl                  = true
  require_cert_auth_for_admin = true

  create_app_user            = true
  app_username               = "appuser"
  app_user_generate_password = true

  export_credentials_to_namespace = "default"
  export_credentials_secret_name  = try(var.config[terraform.workspace].postgres_cnpg.export_credentials_secret_name, "postgres-credentials")

  additional_client_ca_certs = [local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT_DB_CA"]["TELEPORT_DB_CA"]]

  export_ca_to_vault   = true
  vault_ca_secret_path = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_path, "cluster-secret-store/secrets/POSTGRES_CA")
  vault_ca_secret_key  = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_key, "POSTGRES_CA")

  ingress_enabled    = true
  ingress_host       = try(var.config[terraform.workspace].postgres_cnpg.ingress_host, "")
  ingress_class_name = try(var.config[terraform.workspace].postgres_cnpg.ingress_class_name, "traefik")
  use_istio          = try(var.config[terraform.workspace].postgres_cnpg.use_istio, false)
  istio_CRDs         = try(var.config[terraform.workspace].postgres_cnpg.use_istio, false)

  enable_superuser_access = try(var.config[terraform.workspace].postgres_cnpg.enable_superuser_access, true)
  managed_roles           = try(var.config[terraform.workspace].postgres_cnpg.managed_roles, [])

  depends_on = [module.cloudnative_pg_operator]
}

module "postgres_databases" {
  source   = "../modules/base/cnpg-database"
  for_each = { for db in try(var.config[terraform.workspace].postgres_cnpg.databases, []) : db.name => db }

  create        = contains(local.workload, "postgres-cnpg")
  name          = each.value.name
  namespace     = "default"
  database_name = each.value.name
  owner         = each.value.owner
  cluster_name  = "postgres"

  locale_collate = try(each.value.locale_collate, null)
  locale_ctype   = try(each.value.locale_ctype, null)

  depends_on = [module.postgres_cnpg]
}

# module "freqtrade" {
#   count  = contains(local.workload, "freqtrade") ? 1 : 0
#   source = "../modules/apps/freqtrade"

#   environment     = terraform.workspace
#   domain          = var.config[terraform.workspace].freqtrade.domain
#   dry_run         = var.config[terraform.workspace].freqtrade.dry_run
#   stake_amount    = var.config[terraform.workspace].freqtrade.stake_amount
#   max_open_trades = var.config[terraform.workspace].freqtrade.max_open_trades
#   freqai_enabled  = var.config[terraform.workspace].freqtrade.freqai

#   binance_api_key    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_KEY"]
#   binance_api_secret = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_SECRET"]
#   frequi_password    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["FREQUI_PASSWORD"]
#   jwt_secret_key     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["JWT_SECRET_KEY"]
#   telegram_token     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_TOKEN"]
#   telegram_chat_id   = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_CHAT_ID"]

#   minio_endpoint   = "minio.fullstack.pw"
#   minio_bucket     = "freqtrade"
#   minio_access_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootUser"]
#   minio_secret_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]

#   storage_class = "local-path"
#   use_istio     = contains(local.workload, "istio")
#   istio_gateway = "istio-system/default-gateway"
# }

module "cluster_autoscaler" {
  count  = contains(local.workload, "cluster-autoscaler") ? 1 : 0
  source = "../modules/apps/cluster-autoscaler"

  managed_clusters = var.config[terraform.workspace].cluster_autoscaler_managed_clusters
  chart_version    = lookup(var.config[terraform.workspace], "cluster_autoscaler_chart_version", "9.54.0")
  image_tag        = lookup(var.config[terraform.workspace], "cluster_autoscaler_image_tag", "v1.34.2")

  scale_down_enabled         = lookup(var.config[terraform.workspace], "cluster_autoscaler_scale_down_enabled", true)
  scale_down_delay_after_add = lookup(var.config[terraform.workspace], "cluster_autoscaler_scale_down_delay", "10m")
  scale_down_unneeded_time   = lookup(var.config[terraform.workspace], "cluster_autoscaler_unneeded_time", "10m")

  replicas = lookup(var.config[terraform.workspace], "cluster_autoscaler_replicas", 1)
}
