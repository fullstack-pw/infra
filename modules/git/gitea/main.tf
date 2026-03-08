module "namespace" {
  source = "../../base/namespace"

  create        = true
  name          = var.namespace
  needs_secrets = true
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        domain                     = var.domain
        ssh_domain                 = var.ssh_domain
        ssh_port                   = var.ssh_port
        admin_username             = var.admin_username
        admin_password             = var.admin_password
        admin_email                = var.admin_email
        secret_key                 = var.secret_key
        internal_token             = var.internal_token
        external_database_host     = var.external_database_host
        external_database_port     = var.external_database_port
        external_database_name     = var.external_database_name
        external_database_username = var.external_database_username
        external_database_password = var.external_database_password
        external_database_ssl_mode = var.external_database_ssl_mode
        external_redis_host        = var.external_redis_host
        external_redis_port        = var.external_redis_port
        external_redis_password    = var.external_redis_password
        ingress_enabled            = var.ingress_enabled
        ingress_class_name         = var.ingress_class_name
        ingress_annotations        = var.ingress_annotations
        storage_class              = var.storage_class
        storage_size               = var.storage_size
        default_actions_url        = var.default_actions_url
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "gitea"
  repository       = "https://dl.gitea.com/charts/"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values
  set_values       = var.additional_set_values
}
