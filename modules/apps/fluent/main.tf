module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = "default"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  chart_version    = var.chart_version
  create_namespace = false
  force_update     = var.force_update
  timeout          = var.timeout
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        CLUSTER = terraform.workspace
      }
    }
  ]
}
