module "ingress" {
  source = "../../base/ingress"

  enabled            = var.ingress_enabled && !var.use_istio
  name               = "${var.cluster_name}-ingress"
  namespace          = var.namespace
  host               = var.ingress_host
  service_name       = "${var.cluster_name}-rw"
  service_port       = var.service_port
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations = merge({
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "50m"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }, var.ingress_annotations)

  depends_on = [kubernetes_namespace.this, kubernetes_manifest.postgres_cluster]
}

module "istio_gateway" {
  source = "../../base/istio-gateway"

  enabled   = var.ingress_enabled && var.istio_CRDs
  name      = "${var.cluster_name}-gateway"
  namespace = var.istio_gateway_namespace
  hosts     = [var.ingress_host]

  http_enabled  = false
  https_enabled = false

  additional_servers = [
    {
      port = {
        number   = 5432
        name     = "postgresql"
        protocol = "TCP"
      }
      hosts = [var.ingress_host]
    },
    {
      port = {
        number   = 5433
        name     = "postgresql-alt"
        protocol = "TCP"
      }
      hosts = [var.ingress_host]
    }
  ]

  depends_on = [kubernetes_namespace.this]
}

module "istio_virtualservice" {
  source = "../../base/istio-virtualservice"

  enabled      = var.ingress_enabled && var.istio_CRDs
  name         = "${var.cluster_name}-vs"
  namespace    = var.namespace
  hosts        = [var.ingress_host]
  gateways     = ["${var.istio_gateway_namespace}/${var.cluster_name}-gateway"]
  routing_mode = "tcp"

  tcp_routes = [
    {
      match = [
        {
          port = 5432
        }
      ]
      route = [
        {
          destination = {
            host = "${var.cluster_name}-rw.${var.namespace}.svc.cluster.local"
            port = {
              number = var.service_port
            }
          }
        }
      ]
    },
    {
      match = [
        {
          port = 5433
        }
      ]
      route = [
        {
          destination = {
            host = "${var.cluster_name}-rw.${var.namespace}.svc.cluster.local"
            port = {
              number = var.service_port
            }
          }
        }
      ]
    }
  ]

  cluster_issuer = var.cert_manager_cluster_issuer

  depends_on = [module.istio_gateway, kubernetes_namespace.this]
}
