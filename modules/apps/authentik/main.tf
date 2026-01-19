/**
 * Authentik Module
 *
 * This module deploys Authentik identity provider using our base modules for standardization.
 * It supports connecting to external PostgreSQL and Redis instances.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        secret_key     = var.authentik_secret_key
        admin_password = var.admin_password
        admin_email    = var.admin_email

        domain             = var.domain
        ingress_class_name = var.ingress_class_name

        pg_host        = var.postgres_host
        pg_port        = var.postgres_port
        pg_name        = var.postgres_name
        pg_user        = var.postgres_user
        pg_secret_name = var.postgres_secret_name

        redis_host     = var.redis_host
        redis_port     = var.redis_port
        redis_password = var.redis_password
        redis_db       = var.redis_db
      }
    }
  ]
}

data "kubernetes_secret" "postgres" {
  metadata {
    name      = var.postgres_secret_name
    namespace = var.postgres_secret_namespace
  }
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = var.postgres_secret_name
    namespace = module.namespace.name
  }

  data = data.kubernetes_secret.postgres.data
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "authentik"
  repository       = "https://charts.goauthentik.io"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values
  force_update     = false

  set_values = var.additional_set_values

  depends_on = [kubernetes_secret.postgres]
}
