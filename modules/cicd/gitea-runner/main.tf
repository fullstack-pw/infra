module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        gitea_url     = var.gitea_url
        runner_token  = var.runner_token
        runner_name   = var.runner_name
        runner_labels = var.runner_labels
        replicas      = var.replicas
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = var.namespace
  chart            = "act-runner"
  repository       = "https://gitea.com/gitea/helm-chart"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values
}
