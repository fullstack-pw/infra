/**
 * NGINX Ingress Controller Module
 * 
 * This module deploys the NGINX ingress controller using our base modules for standardization.
 */

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        enable_custom_resources = var.enable_custom_resources
        enable_snippets         = var.enable_snippets
        default_tls_secret      = var.default_tls_secret
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = var.namespace
  chart            = "nginx-ingress"
  repository       = "https://helm.nginx.com/stable"
  chart_version    = var.chart_version
  create_namespace = var.create_namespace
  timeout          = var.timeout
  atomic           = var.atomic
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}
