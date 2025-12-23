module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace

  labels = {
    "kubernetes.io/metadata.name"        = var.namespace
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/audit"   = "privileged"
    "pod-security.kubernetes.io/warn"    = "privileged"
  }
}

module "helm" {
  source = "../../base/helm"

  release_name     = "local-path-provisioner"
  namespace        = module.namespace.name
  chart            = "local-path-provisioner"
  repository       = "https://charts.containeroo.ch"
  chart_version    = var.chart_version
  timeout          = 300
  create_namespace = false

  values_files = [
    <<-EOT
      nodePathMap:
        - node: DEFAULT_PATH_FOR_NON_LISTED_NODES
          paths:
            - /var/lib/local-path-provisioner

      storageClass:
        name: ${var.storage_class_name}
        defaultClass: ${var.set_default_storage_class}

      resources:
        limits:
          cpu: 100m
          memory: 128Mi
        requests:
          cpu: 10m
          memory: 32Mi
    EOT
  ]

  set_values = []
}
