/**
 * Istio VirtualService Base Module
 *
 * This module creates an Istio VirtualService for HTTP/HTTPS and TLS/TCP routing.
 * VirtualServices define the rules for routing traffic to services.
 * They work together with Gateways to expose services externally.
 */

locals {
  use_multiple_routes = length(var.routes) > 0
  include_http        = var.routing_mode == "http" || var.routing_mode == "both"
  include_tls         = var.routing_mode == "tls" || var.routing_mode == "both"

  http_routes = local.use_multiple_routes ? [
    for route in var.routes : {
      match = lookup(route, "match", null)
      route = [
        for dest in route.route : {
          destination = {
            host = dest.destination.host
            port = lookup(dest.destination, "port", null) != null ? {
              number = dest.destination.port.number
            } : null
            subset = lookup(dest.destination, "subset", null)
          }
          weight  = lookup(dest, "weight", null)
          headers = lookup(dest, "headers", null)
        }
      ]
      timeout = lookup(route, "timeout", null)
      retries = lookup(route, "retries", null) != null ? {
        attempts      = lookup(route.retries, "attempts", 3)
        perTryTimeout = lookup(route.retries, "perTryTimeout", "2s")
        retryOn       = lookup(route.retries, "retryOn", "5xx,reset,connect-failure,refused-stream")
      } : null
      corsPolicy = lookup(route, "cors", null)
      headers    = lookup(route, "headers", null)
      rewrite    = lookup(route, "rewrite", null)
      redirect   = lookup(route, "redirect", null)
      fault      = lookup(route, "fault", null)
      mirror     = lookup(route, "mirror", null)
    }
    ] : [
    {
      match = [{
        uri = {
          prefix = var.path
        }
      }]
      route = [{
        destination = {
          host = var.service_name
          port = {
            number = var.service_port
          }
        }
      }]
      timeout    = var.timeout
      retries    = var.retries
      corsPolicy = var.cors
      headers    = var.headers
      rewrite    = var.rewrite
    }
  ]
}

resource "kubernetes_manifest" "virtualservice" {
  count = var.enabled ? 1 : 0

  computed_fields = ["spec"]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = var.name
      namespace = var.namespace
      annotations = merge(
        var.default_annotations ? {
          "cert-manager.io/cluster-issuer" = var.cluster_issuer
        } : {},
        var.annotations
      )
    }
    spec = merge(
      {
        hosts    = var.hosts
        gateways = var.gateways
      },
      local.include_http ? { http = local.http_routes } : {},
      local.include_tls ? { tls = var.tls_routes } : {}
    )
  }
}
