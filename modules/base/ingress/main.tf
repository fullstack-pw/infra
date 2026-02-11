/**
 * Base ingress module
 *
 * This module creates a standard Kubernetes ingress with common annotations.
 * Supports multiple paths and port names.
 */

locals {
  # Determine if we should use the legacy single path mode or the new multiple paths mode
  use_multiple_paths = length(var.paths) > 0

  # If no paths are provided, create a default path using the legacy parameters
  default_paths = [{
    path      = var.path
    path_type = var.path_type
    backend = {
      service_name      = var.service_name
      service_port      = var.service_port
      service_port_name = var.service_port_name
    }
  }]

  # Use the paths provided or the default path
  effective_paths = local.use_multiple_paths ? var.paths : local.default_paths
}

resource "kubernetes_ingress_v1" "this" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = merge(
      var.default_annotations ? {
        "nginx.ingress.kubernetes.io/ssl-redirect"  = tostring(var.tls_enabled)
        "external-dns.alpha.kubernetes.io/hostname" = var.host
        "cert-manager.io/cluster-issuer"            = var.cluster_issuer
      } : {},
      var.annotations
    )
  }

  spec {
    ingress_class_name = var.ingress_class_name

    rule {
      host = var.host
      http {
        dynamic "path" {
          for_each = local.effective_paths
          content {
            path      = path.value.path
            path_type = path.value.path_type
            backend {
              service {
                name = path.value.backend.service_name != null ? path.value.backend.service_name : var.service_name
                port {
                  # Use either port number or port name based on which is provided
                  name   = path.value.backend.service_port_name != null ? path.value.backend.service_port_name : var.service_port_name
                  number = path.value.backend.service_port != null ? path.value.backend.service_port : var.service_port
                }
              }
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = var.tls_enabled ? [1] : []
      content {
        hosts       = [var.host]
        secret_name = var.tls_secret_name != "" ? var.tls_secret_name : "${replace(var.host, ".", "-")}-tls"
      }
    }
  }
}
