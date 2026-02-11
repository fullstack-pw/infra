/**
 * Base namespace module
 *
 * This module creates a Kubernetes namespace with optional labels and annotations.
 */

resource "kubernetes_namespace" "this" {
  count = var.create ? 1 : 0

  metadata {
    name = var.name
    labels = merge(
      var.labels,
      var.add_cluster_secretstore_label ? {
        "kubernetes.io/metadata.name" = var.name
      } : {},
      var.needs_secrets ? {
        "cluster-secrets" = "true"
      } : {}
    )
    annotations = var.annotations
  }
}

locals {
  namespace = var.create ? kubernetes_namespace.this[0].metadata[0].name : var.name
}
