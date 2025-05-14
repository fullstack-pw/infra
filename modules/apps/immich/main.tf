module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

module "base" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = var.namespace
  chart            = var.chart
  repository       = var.repository
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = var.create_namespace

  values_files = [templatefile("${path.module}/templates/base.yaml.tpl", {
    redis                   = var.redis
    redis_pass              = var.redis_pass
    db_hostname             = var.db_hostname
    db_user                 = var.db_user
    db_name                 = var.db_name
    db_pass                 = var.db_pass
    immich_domain           = var.immich_domain
    ingress_tls_secret_name = var.ingress_tls_secret_name
    ingress_annotations     = var.ingress_annotations
  })]

  set_values = concat([], var.base_additional_set_values)
}
