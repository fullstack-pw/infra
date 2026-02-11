/**
 * Base Helm module
 *
 * This module standardizes Helm chart deployments.
 */

resource "helm_release" "this" {
  name             = var.release_name
  namespace        = var.namespace
  repository       = var.repository
  chart            = var.chart
  version          = var.chart_version
  create_namespace = var.create_namespace
  timeout          = var.timeout
  atomic           = var.atomic
  values           = var.values_files
  force_update     = var.force_update

  dynamic "set" {
    for_each = var.set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  dynamic "set_sensitive" {
    for_each = var.set_sensitive_values
    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
    }
  }
}
