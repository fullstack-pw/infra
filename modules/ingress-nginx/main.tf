
resource "helm_release" "nginx" {
  name             = var.release_name
  namespace        = var.namespace
  chart            = "nginx-ingress"
  repository       = "https://helm.nginx.com/stable"
  version          = var.chart_version
  create_namespace = var.create_namespace
  timeout          = var.timeout
  atomic           = var.atomic

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      enable_custom_resources = var.enable_custom_resources
      enable_snippets         = var.enable_snippets
      default_tls_secret      = var.default_tls_secret
    })
  ]

  dynamic "set" {
    for_each = var.additional_set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}

