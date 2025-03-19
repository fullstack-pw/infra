/**
 * Base ingress module
 * 
 * This module creates a standard Kubernetes ingress with common annotations.
 */

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
        path {
          path      = var.path
          path_type = var.path_type
          backend {
            service {
              name = var.service_name
              port {
                number = var.service_port
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
        secret_name = var.tls_secret_name
      }
    }
  }
}
