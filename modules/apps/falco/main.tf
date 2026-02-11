module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
  labels = {
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/audit"   = "privileged"
    "pod-security.kubernetes.io/warn"    = "privileged"
  }
}

module "falco_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        memory_limit    = var.memory_limit
        cpu_limit       = var.cpu_limit
        memory_request  = var.memory_request
        cpu_request     = var.cpu_request
        driver_kind     = var.driver_kind
        metrics_enabled = var.enable_metrics
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = "falco"
  namespace        = module.namespace.name
  create_namespace = false
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  chart_version    = var.chart_version
  timeout          = var.timeout
  values_files     = module.falco_values.rendered_values
}
