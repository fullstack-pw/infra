/**
 * Harbor Module
 *
 * This module deploys Harbor container registry using our base modules for standardization.
 * It supports connecting to external PostgreSQL and Redis instances, such as those in the tools cluster.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

# Generate admin password if not provided
resource "random_password" "admin_password" {
  count   = var.generate_admin_password ? 1 : 0
  length  = 16
  special = false
}

locals {
  admin_password = var.generate_admin_password ? random_password.admin_password[0].result : var.admin_password
}

# Store Harbor credentials in a Kubernetes secret
module "credentials" {
  source = "../../base/credentials"

  name              = "${var.release_name}-credentials"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = true

  data = {
    admin_username    = "admin"
    admin_password    = local.admin_password
    postgres_host     = var.external_database_host
    postgres_port     = tostring(var.external_database_port)
    postgres_user     = var.external_database_username
    postgres_password = var.external_database_password
    redis_host        = var.external_redis_host
    redis_port        = tostring(var.external_redis_port)
    redis_password    = var.external_redis_password
    harbor_url        = "https://${var.harbor_domain}"
  }
}

# Create an initial PostgreSQL database for Harbor
# This assumes that you're using the PostgreSQL module from tools cluster
# and that you can configure it to create a database for Harbor
resource "vault_kv_secret_v2" "harbor_database" {
  mount               = "kv"
  name                = "cluster-secret-store/secrets/HARBOR_DB"
  delete_all_versions = true
  data_json = jsonencode({
    POSTGRES_DATABASE = var.external_database_database
    POSTGRES_HOST     = var.external_database_host
    POSTGRES_PORT     = var.external_database_port
    POSTGRES_USER     = var.external_database_username
    POSTGRES_PASSWORD = var.external_database_password
  })
}

# Render the Helm values template
module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        # Admin credentials
        admin_password = local.admin_password

        # Domains
        harbor_domain = var.harbor_domain
        notary_domain = var.notary_domain

        # Ingress configuration
        ingress_enabled      = var.ingress_enabled
        ingress_class_name   = var.ingress_class_name
        ingress_annotations  = var.ingress_annotations
        tls_enabled          = var.tls_enabled
        tls_cert_secret_name = var.tls_cert_secret_name

        # Persistence
        persistence_enabled = var.persistence_enabled
        storage_class       = var.storage_class

        # External database
        external_database_host     = var.external_database_host
        external_database_port     = var.external_database_port
        external_database_username = var.external_database_username
        external_database_password = var.external_database_password
        external_database_sslmode  = var.external_database_sslmode
        external_database_database = var.external_database_database

        # External Redis
        external_redis_host           = var.external_redis_host
        external_redis_port           = var.external_redis_port
        external_redis_password       = var.external_redis_password
        external_redis_database_index = var.external_redis_database_index

        # Resource limits
        resources_limits   = var.resources_limits
        resources_requests = var.resources_requests
      }
    }
  ]
}

# Deploy Harbor using Helm
module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "harbor"
  repository       = "https://helm.goharbor.io"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values
  force_update     = false

  set_values = var.additional_set_values

  depends_on = [
    vault_kv_secret_v2.harbor_database
  ]
}

# Create ingress for Harbor core if not created by Helm
module "core_ingress" {
  source = "../../base/ingress"
  count  = var.ingress_enabled && !var.tls_enabled ? 1 : 0

  enabled            = true
  name               = "${var.release_name}-core-ingress"
  namespace          = module.namespace.name
  host               = var.harbor_domain
  service_name       = "${var.release_name}-harbor-core"
  service_port       = 80
  path               = "/"
  path_type          = "Prefix"
  tls_enabled        = var.tls_enabled
  tls_secret_name    = var.tls_cert_secret_name
  ingress_class_name = var.ingress_class_name
  annotations        = var.ingress_annotations
}

# Create ingress for Harbor portal if not created by Helm
module "portal_ingress" {
  source = "../../base/ingress"
  count  = var.ingress_enabled && !var.tls_enabled ? 1 : 0

  enabled            = true
  name               = "${var.release_name}-portal-ingress"
  namespace          = module.namespace.name
  host               = var.harbor_domain
  service_name       = "${var.release_name}-harbor-portal"
  service_port       = 80
  path               = "/"
  path_type          = "Prefix"
  tls_enabled        = var.tls_enabled
  tls_secret_name    = var.tls_cert_secret_name
  ingress_class_name = var.ingress_class_name
  annotations        = var.ingress_annotations
}
