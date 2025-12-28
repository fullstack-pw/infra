resource "helm_release" "cloudnative_pg" {
  name       = "cnpg"
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = var.chart_version
  namespace  = var.namespace

  create_namespace = var.create_namespace

  values = [
    yamlencode({
      crds = {
        create = true
      }
    })
  ]
}
