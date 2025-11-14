module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  deployment_name      = "external-dns-pihole"
  dns_provider         = "pihole"
  create_pihole_secret = terraform.workspace == "sandbox" ? true : false
  pihole_password      = terraform.workspace == "sandbox" ? local.secrets_json["kv/cluster-secret-store/secrets/EXTERNAL_DNS_PIHOLE_PASSWORD"]["PIHOLE_PASSWORD"] : ""
}

module "externaldns_cloudflare" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  deployment_name          = "external-dns-cloudflare"
  dns_provider             = "cloudflare"
  create_cloudflare_secret = true
  cloudflare_api_token     = local.secrets_json["kv/cloudflare"]["api-token"]
  container_args = [
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

  # Gateway configuration - K3s has built-in ServiceLB (Klipper-LB)
  gateway_service_type = "LoadBalancer"

  # Control plane configuration
  pilot_replicas   = 1
  gateway_replicas = 1

  # Enable telemetry and observability
  enable_telemetry = true
  enable_tracing   = false # Can be enabled later to integrate with Jaeger
  access_log_file  = "/dev/stdout"

  # IMPORTANT: Set to false for initial deployment, then set to true after CRDs are installed
  # This avoids the chicken-and-egg problem with Terraform validating manifests during plan
  create_default_gateway = true # TODO: Change to true after first apply
  default_tls_secret     = "default-gateway-tls"

  # Certificate configuration for default gateway
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

  prometheus_namespaces = var.config[terraform.workspace].prometheus_namespaces
}

module "postgres" {
  count  = contains(local.workload, "postgres") ? 1 : 0
  source = "../modules/apps/postgres"
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
  db_hostname   = "postgres.fullstack.pw"
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

module "teleport-agent" {
  count  = contains(local.workload, "teleport-agent") ? 1 : 0
  source = "../modules/apps/teleport-agent"

  kubernetes_cluster_name = terraform.workspace
  join_token              = "76756646e90d1f740646aa5e30fdd216"
  roles                   = var.config[terraform.workspace].teleport.roles
  apps                    = var.config[terraform.workspace].teleport.apps
  databases               = var.config[terraform.workspace].teleport.databases
}

module "testing_postgres" {
  count  = contains(local.workload, "dev-postgres") ? 1 : 0
  source = "../modules/apps/postgres"

  memory_request          = "512Mi"
  cpu_request             = "250m"
  memory_limit            = "1Gi"
  cpu_limit               = "500m"
  ingress_host            = "dev.postgres.fullstack.pw"
  ingress_tls_secret_name = "postgres-tls"
  enable_ssl              = true
  ssl_ca_cert_key         = "SSL_CA"
  ssl_server_cert_key     = "SSL_CERT"
  ssl_server_key_key      = "SSL_KEY"

  # Application user for password-based authentication
  create_app_user            = true
  app_username               = "appuser"
  app_user_generate_password = true

  # IMPORTANT: Set to false for initial deployment, then set to true after Istio CRDs are installed
  # This avoids the chicken-and-egg problem with Terraform validating manifests during plan
  use_istio               = true # TODO: Change to true after Istio is deployed
  istio_gateway_namespace = "istio-system"
  istio_gateway_name      = "istio-system/default-gateway"
  ingress_class_name      = "istio"
}
