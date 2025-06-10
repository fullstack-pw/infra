/**
 * Longhorn Module
 * 
 * This module deploys Longhorn distributed storage system using our base modules.
 * Longhorn provides persistent storage for Kubernetes workloads with features like
 * snapshots, backups, and disaster recovery.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
    "longhorn.io/managed"         = "true"
  }
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        replica_count           = var.replica_count
        image_pull_policy       = var.image_pull_policy
        service_account         = var.service_account
        default_settings        = var.default_settings
        ingress_enabled         = var.ingress_enabled
        ingress_class_name      = var.ingress_class_name
        ingress_host            = var.ingress_host
        ingress_tls_enabled     = var.ingress_tls_enabled
        ingress_tls_secret_name = var.ingress_tls_secret_name
        ingress_annotations     = var.ingress_annotations
        enable_psp              = var.enable_psp
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = "longhorn"
  namespace        = module.namespace.name
  chart            = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}
