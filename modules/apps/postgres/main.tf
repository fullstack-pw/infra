module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "credentials" {
  source = "../../base/credentials"

  name              = "${var.release_name}-credentials"
  namespace         = module.namespace.name
  generate_password = var.generate_credentials
  password          = var.postgres_password
  password_key      = "password"
  create_secret     = var.create_credentials_secret

  data = {
    username          = local.postgres_username
    database          = local.postgres_database
    password          = local.postgres_password
    postgres_host     = "${var.release_name}-postgresql.${module.namespace.name}.svc.cluster.local"
    postgres_port     = var.service_port
    connection_string = "postgresql://${local.postgres_username}:${var.generate_credentials ? module.credentials.password : var.postgres_password}@${var.release_name}-postgresql.${module.namespace.name}.svc.cluster.local:${var.service_port}/${local.postgres_database}"
  }
}

resource "vault_kv_secret_v2" "postgres_password" {
  count = var.store_password_in_vault ? 1 : 0

  mount               = var.vault_mount_path
  name                = var.vault_secret_path
  delete_all_versions = true
  data_json = jsonencode(
    merge(
      jsondecode(var.preserve_existing_vault_data ? data.vault_kv_secret_v2.existing_secret[0].data_json : "{}"),
      {
        "POSTGRES_PASSWORD" = module.credentials.password
        "POSTGRES_USER"     = local.postgres_username
        "POSTGRES_HOST"     = "${var.release_name}-postgresql.${module.namespace.name}.svc.cluster.local"
        "POSTGRES_PORT"     = var.service_port
        "POSTGRES_DATABASE" = local.postgres_database
      }
    )
  )

  depends_on = [module.credentials]
}
data "vault_kv_secret_v2" "existing_secret" {
  count = var.store_password_in_vault && var.preserve_existing_vault_data ? 1 : 0

  mount = var.vault_mount_path
  name  = var.vault_secret_path

  depends_on = [module.credentials]
}
locals {
  postgres_username = var.generate_credentials ? "admin" : var.postgres_username
  postgres_database = var.postgres_database != "" ? var.postgres_database : "postgres"
  postgres_password = var.generate_credentials ? module.credentials.password : var.postgres_password
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        pg_version                         = var.postgres_version
        postgres_username                  = local.postgres_username
        postgres_password                  = module.credentials.password
        postgres_database                  = local.postgres_database
        persistence_enabled                = var.persistence_enabled
        storage_class                      = var.persistence_storage_class
        persistence_size                   = var.persistence_size
        memory_request                     = var.memory_request
        cpu_request                        = var.cpu_request
        memory_limit                       = var.memory_limit
        cpu_limit                          = var.cpu_limit
        enable_metrics                     = var.enable_metrics
        service_type                       = var.service_type
        service_port                       = var.service_port
        registry                           = var.registry
        repository                         = var.repository
        replication_enabled                = var.replication_enabled
        replication_replicas               = var.replication_replicas
        replication_synchronousCommit      = var.replication_synchronousCommit
        replication_numSynchronousReplicas = var.replication_numSynchronousReplicas
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "postgresql"
  repository       = "https://charts.bitnami.com/bitnami"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

module "ingress" {
  source = "../../base/ingress"

  enabled            = var.ingress_enabled
  name               = "${var.release_name}-postgresql-ingress"
  namespace          = module.namespace.name
  host               = var.ingress_host
  service_name       = "${var.release_name}-postgresql"
  service_port       = var.service_port
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations = merge({
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "50m"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }, var.ingress_annotations)
}
