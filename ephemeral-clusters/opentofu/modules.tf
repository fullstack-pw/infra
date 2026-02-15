resource "kubernetes_labels" "default_namespace" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }
  labels = {
    "cluster-secrets" = "true"
  }
}

module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../../modules/apps/externaldns"

  deployment_name      = "external-dns-pihole"
  dns_provider         = "pihole"
  create_pihole_secret = terraform.workspace == "sandbox" ? true : false
  pihole_password      = terraform.workspace == "sandbox" ? local.secrets_json["kv/cluster-secret-store/secrets/EXTERNAL_DNS_PIHOLE_PASSWORD"]["PIHOLE_PASSWORD"] : ""

  crds_installed = var.config[terraform.workspace].crds_installed
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
  source = "../../modules/apps/externaldns"

  crds_installed           = var.config[terraform.workspace].crds_installed
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
  source = "../../modules/apps/certmanager"

  install_crd       = var.config[terraform.workspace].crds_installed
  cloudflare_secret = local.secrets_json["kv/cloudflare"]["api-token"]
}

module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../../modules/apps/external-secrets"

  install_crd = var.config[terraform.workspace].crds_installed
  secret_data = local.secret_data
  vault_token = local.secrets_json["kv/cluster-secret-store/secrets/VAULT_TOKEN"]["VAULT_TOKEN"]

  namespace_selector_type = "label"
  namespace_selector_label = {
    key   = "cluster-secrets"
    value = "true"
  }
}

module "argocd" {
  count  = contains(local.workload, "argocd") ? 1 : 0
  source = "../../modules/apps/argocd"

  namespace              = "argocd"
  install_argocd         = terraform.workspace == "tools"
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
  istio_CRDs             = false
}

module "observability-box" {
  count  = contains(local.workload, "observability-box") ? 1 : 0
  source = "../../modules/apps/observability-box"

  prometheus_namespaces     = try(var.config[terraform.workspace].prometheus_namespaces, [])
  prometheus_memory_limit   = try(var.config[terraform.workspace].prometheus_memory_limit, "1024Mi")
  prometheus_memory_request = try(var.config[terraform.workspace].prometheus_memory_request, "256Mi")
  prometheus_storage_size   = try(var.config[terraform.workspace].prometheus_storage_size, "")
}

data "vault_kv_secret_v2" "postgres_ca" {
  for_each = local.postgres_ca_secrets
  mount    = "kv"
  name     = "cluster-secret-store/secrets/${each.key}"
}

module "cloudnative_pg_operator" {
  count  = contains(local.workload, "cloudnative-pg-operator") ? 1 : 0
  source = "../../modules/apps/cloudnative-postgres-operator"

  namespace        = "cnpg-system"
  create_namespace = true
  chart_version    = "0.27.0"
}

module "postgres_cnpg" {
  count  = contains(local.workload, "postgres-cnpg") ? 1 : 0
  source = "../../modules/apps/cloudnative-postgres"

  cluster_name     = "postgres"
  namespace        = "default"
  create_namespace = false
  create_cluster   = try(var.config[terraform.workspace].postgres_cnpg.crds_installed, false)

  registry   = "registry.fullstack.pw"
  repository = "library/cloudnative-postgres"
  pg_version = "latest"

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

  export_ca_to_vault   = false
  vault_ca_secret_path = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_path, "cluster-secret-store/secrets/POSTGRES_CA")
  vault_ca_secret_key  = try(var.config[terraform.workspace].postgres_cnpg.vault_ca_secret_key, "POSTGRES_CA")

  ingress_enabled    = true
  ingress_host       = try(var.config[terraform.workspace].postgres_cnpg.ingress_host, "")
  ingress_class_name = try(var.config[terraform.workspace].postgres_cnpg.ingress_class_name, "traefik")
  use_istio          = try(var.config[terraform.workspace].postgres_cnpg.use_istio, false)
  istio_CRDs         = try(var.config[terraform.workspace].istio_CRDs, false)

  enable_superuser_access = try(var.config[terraform.workspace].postgres_cnpg.enable_superuser_access, true)
  managed_roles           = try(var.config[terraform.workspace].postgres_cnpg.managed_roles, [])

  depends_on = [module.cloudnative_pg_operator]
}

module "postgres_databases" {
  source   = "../../modules/base/cnpg-database"
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
