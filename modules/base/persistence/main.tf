/**
 * Base persistence module
 * 
 * This module creates a standard Kubernetes PVC with common configurations.
 */

resource "kubernetes_persistent_volume_claim" "this" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = var.labels
  }

  spec {
    access_modes       = var.access_modes
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.size
      }
    }

    # Only include selector if explicitly enabled
    dynamic "selector" {
      for_each = var.use_selector && length(var.selector_labels) > 0 ? [1] : []
      content {
        match_labels = var.selector_labels
      }
    }
  }
}
