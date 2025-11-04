/**
 * Istio Gateway Base Module
 *
 * This module creates an Istio Gateway resource for ingress traffic.
 * A Gateway describes a load balancer operating at the edge of the mesh.
 * It typically pairs with VirtualServices for routing.
 */

resource "kubernetes_manifest" "gateway" {
  count = var.enabled ? 1 : 0

  # Wait for Istio CRD to be available before validating
  computed_fields = ["spec"]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = var.name
      namespace = var.namespace
      annotations = merge(
        var.default_annotations ? {
          "external-dns.alpha.kubernetes.io/hostname" = join(",", var.hosts)
        } : {},
        var.annotations
      )
    }
    spec = {
      selector = var.selector
      servers = concat(
        # HTTP server with optional HTTPS redirect
        var.http_enabled ? [
          {
            port = {
              number   = 80
              name     = "http"
              protocol = "HTTP"
            }
            hosts = var.hosts
            tls = var.https_redirect ? {
              httpsRedirect = true
            } : null
          }
        ] : [],
        # HTTPS server with TLS
        var.https_enabled ? [
          {
            port = {
              number   = 443
              name     = "https"
              protocol = "HTTPS"
            }
            hosts = var.hosts
            tls = {
              mode           = var.tls_mode
              credentialName = var.tls_secret_name != "" ? var.tls_secret_name : "${replace(var.hosts[0], ".", "-")}-tls"
              minProtocolVersion = var.tls_min_version
            }
          }
        ] : [],
        # Additional custom servers
        var.additional_servers
      )
    }
  }
}
