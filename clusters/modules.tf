module "local_path_provisioner" {
  count  = contains(local.workload, "local-path-provisioner") ? 1 : 0
  source = "../modules/apps/local-path-provisioner"

  namespace                 = "local-path-storage"
  storage_class_name        = "local-path"
  set_default_storage_class = true
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

module "postgres" {
  count      = contains(local.workload, "postgres") ? 1 : 0
  source     = "../modules/apps/postgres"
  istio_CRDs = false
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

  external_database_host     = "tools-postgres-rw.tools-postgres.svc.cluster.local"
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

module "proxmox_talos_clusters" {
  count  = contains(keys(var.config[terraform.workspace]), "proxmox-talos-cluster") ? 1 : 0
  source = "../modules/apps/proxmox-talos-cluster"

  clusters = var.config[terraform.workspace].proxmox-talos-cluster

  cluster_api_dependencies = []

  create_proxmox_secret = true
  proxmox_url           = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret        = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token         = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]
}

module "proxmox_kubeadm_clusters" {
  count  = contains(keys(var.config[terraform.workspace]), "proxmox-kubeadm-cluster") ? 1 : 0
  source = "../modules/apps/proxmox-kubeadm-cluster"

  clusters = var.config[terraform.workspace].proxmox-kubeadm-cluster

  cluster_api_dependencies = contains(local.workload, "clusterapi-operator") ? [module.clusterapi_operator[0]] : []

  create_proxmox_secret = true
  proxmox_url           = element(split("/api2", local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_URL"]["PROXMOX_URL"]), 0)
  proxmox_secret        = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_SECRET"]["PROXMOX_SECRET"]
  proxmox_token         = local.secrets_json["kv/cluster-secret-store/secrets/PROXMOX_TOKEN_ID"]["PROXMOX_TOKEN_ID"]

  ssh_authorized_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9"
  ]
}

module "teleport-agent" {
  count  = contains(local.workload, "teleport-agent") ? 1 : 0
  source = "../modules/apps/teleport-agent"

  kubernetes_cluster_name = terraform.workspace
  join_token              = "2875dbe2e37eac947af86de3b0631e45"
  ca_pin                  = "sha256:7f9b9e8c1ec072c967ac3f6693f88f3e464a1e6e34e76a6e4d7e97502eb0a93c"
  roles                   = var.config[terraform.workspace].teleport.roles
  apps                    = var.config[terraform.workspace].teleport.apps
  databases = {
    for name, db in var.config[terraform.workspace].teleport.databases : name => {
      uri     = db.uri
      ca_cert = db.ca_cert != "" ? local.secrets_json["kv/cluster-secret-store/secrets/${db.ca_cert}"][db.ca_cert] : ""
    }
  }
}

module "cloudnative_pg_operator" {
  count  = contains(local.workload, "cloudnative-pg-operator") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres-operator"

  namespace        = "cnpg-system"
  create_namespace = true
  chart_version    = "0.22.1"
}

module "dev_postgres_cnpg" {
  count  = contains(local.workload, "dev-postgres-cnpg") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres"

  cluster_name     = "dev-postgres"
  namespace        = "dev-postgres"
  create_namespace = true
  create_cluster   = true # Set to true after operator CRDs are installed

  # Image configuration
  registry   = "ghcr.io"
  repository = "cloudnative-pg/postgresql" # Use CloudNativePG's PostgreSQL image
  pg_version = "15"

  # Database configuration
  postgres_database          = "postgres"
  postgres_username          = "admin"
  postgres_generate_password = true

  # Storage
  persistence_size = "1Gi"
  storage_class    = "" # Use default

  # Resources
  memory_request = "512Mi"
  cpu_request    = "250m"
  memory_limit   = "1Gi"
  cpu_limit      = "500m"

  # SSL - Enable hostssl in pg_hba.conf but let CNPG manage its own server certificates
  # use_custom_server_certs=false (default) means CNPG generates and manages server certs
  enable_ssl = true

  # Application user
  create_app_user            = true
  app_username               = "appuser"
  app_user_generate_password = true

  # Vault
  needs_secrets     = true
  vault_secret_path = "cluster-secret-store/secrets/DEV_POSTGRES"

  # Export credentials to default namespace for writer app
  export_credentials_to_namespace = "default"
  export_credentials_secret_name  = "dev-postgres-credentials"

  # Additional client CA for Teleport database access
  additional_client_ca_certs = [local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT_DB_CA"]["TELEPORT_DB_CA"]]

  # External access via Istio
  ingress_enabled = true
  ingress_host    = "dev.postgres.fullstack.pw"
  use_istio       = true
  istio_CRDs      = true

  depends_on = [module.cloudnative_pg_operator]
}

module "tools_postgres_cnpg" {
  count  = contains(local.workload, "tools-postgres-cnpg") ? 1 : 0
  source = "../modules/apps/cloudnative-postgres"

  cluster_name     = "tools-postgres"
  namespace        = "tools-postgres"
  create_namespace = true
  create_cluster   = true

  # Image configuration
  registry   = "registry.fullstack.pw"
  repository = "library/postgresql"
  pg_version = "15-wal2json"
  # registry   = "ghcr.io"
  # repository = "cloudnative-pg/postgresql"
  # pg_version = "15"
  # Database configuration
  postgres_database          = "postgres"
  postgres_username          = "admin"
  postgres_generate_password = false
  postgres_password          = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]

  # Storage
  persistence_size = "10Gi"
  storage_class    = ""

  # Resources
  memory_request = "512Mi"
  cpu_request    = "250m"
  memory_limit   = "1Gi"
  cpu_limit      = "500m"

  # SSL - Enable hostssl in pg_hba.conf but let CNPG manage its own server certificates
  enable_ssl = true

  # Allow password auth for admin user from external networks (Teleport server uses password auth)
  require_cert_auth_for_admin = true

  # No app user needed for tools cluster
  create_app_user = false

  # Additional databases for Harbor and Teleport
  additional_databases = ["registry", "teleport_backend", "teleport_audit"]

  # Teleport user with password auth for Teleport server backend
  additional_users = [
    {
      username  = "teleport"
      password  = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
      databases = ["teleport_backend", "teleport_audit"]
    }
  ]

  # Vault - don't write to vault, use existing POSTGRES secret
  needs_secrets = false

  # No credential export needed for tools cluster
  export_credentials_to_namespace = ""

  # Additional client CA for Teleport database access
  additional_client_ca_certs = [local.secrets_json["kv/cluster-secret-store/secrets/TELEPORT_DB_CA"]["TELEPORT_DB_CA"]]

  # Ingress via Traefik (tools cluster uses traefik, not istio)
  ingress_enabled    = true
  ingress_host       = "tools.postgres.fullstack.pw"
  ingress_class_name = "traefik"
  use_istio          = false

  depends_on = [module.cloudnative_pg_operator]
}

module "freqtrade" {
  count  = contains(local.workload, "freqtrade") ? 1 : 0
  source = "../modules/apps/freqtrade"

  environment     = terraform.workspace
  domain          = var.config[terraform.workspace].freqtrade.domain
  dry_run         = var.config[terraform.workspace].freqtrade.dry_run
  stake_amount    = var.config[terraform.workspace].freqtrade.stake_amount
  max_open_trades = var.config[terraform.workspace].freqtrade.max_open_trades
  freqai_enabled  = var.config[terraform.workspace].freqtrade.freqai

  binance_api_key    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_KEY"]
  binance_api_secret = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["BINANCE_API_SECRET"]
  frequi_password    = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["FREQUI_PASSWORD"]
  jwt_secret_key     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["JWT_SECRET_KEY"]
  telegram_token     = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_TOKEN"]
  telegram_chat_id   = local.secrets_json["kv/cluster-secret-store/secrets/FREQTRADE"]["TELEGRAM_CHAT_ID"]

  minio_endpoint   = "minio.fullstack.pw"
  minio_bucket     = "freqtrade"
  minio_access_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootUser"]
  minio_secret_key = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]

  storage_class = "local-path"
  use_istio     = contains(local.workload, "istio")
  istio_gateway = "istio-system/default-gateway"
}

