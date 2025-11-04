/**
 * Istio Module
 *
 * This module deploys Istio service mesh with ingress gateway.
 * Installs Istio base, istiod (control plane), and ingress gateway.
 */

// Create istio-system namespace
module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
    "istio-injection"              = "enabled"
  }
}

// Deploy Istio base chart (CRDs and cluster roles)
// This chart installs ALL Istio CRDs including Gateway, VirtualService,
// DestinationRule, ServiceEntry, AuthorizationPolicy, and 30+ others.
// No manual CRD installation required - Helm manages the full lifecycle.
module "istio_base" {
  source = "../../base/helm"

  release_name     = "istio-base"
  namespace        = module.namespace.name
  chart            = "base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart_version    = var.istio_version
  timeout          = 300
  create_namespace = false
  values_files     = []
  set_values       = []
}

// Deploy istiod (Istio control plane)
module "istiod" {
  source     = "../../base/helm"
  depends_on = [module.istio_base]

  release_name     = "istiod"
  namespace        = module.namespace.name
  chart            = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart_version    = var.istio_version
  timeout          = 300
  create_namespace = false
  values_files = [
    templatefile("${path.module}/templates/istiod-values.yaml.tpl", {
      pilot_replicas     = var.pilot_replicas
      enable_telemetry   = var.enable_telemetry
      access_log_file    = var.access_log_file
      enable_tracing     = var.enable_tracing
      tracing_endpoint   = var.tracing_endpoint
    })
  ]
  set_values = []
}

// Deploy Istio Ingress Gateway
module "istio_ingress" {
  source     = "../../base/helm"
  depends_on = [module.istiod]

  release_name     = "istio-ingressgateway"
  namespace        = module.namespace.name
  chart            = "gateway"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart_version    = var.istio_version
  timeout          = 300
  create_namespace = false
  values_files = [
    templatefile("${path.module}/templates/gateway-values.yaml.tpl", {
      gateway_replicas = var.gateway_replicas
      service_type     = var.gateway_service_type
      load_balancer_ip = var.gateway_load_balancer_ip
      node_port_http   = var.gateway_node_port_http
      node_port_https  = var.gateway_node_port_https
    })
  ]
  set_values = []
}

// Create Certificate resource for default Gateway TLS
// This tells cert-manager to provision a wildcard certificate
resource "kubernetes_manifest" "default_certificate" {
  count      = var.create_default_gateway ? 1 : 0
  depends_on = [module.istio_base]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.default_tls_secret
      namespace = module.namespace.name
    }
    spec = {
      secretName = var.default_tls_secret
      issuerRef = {
        name = var.cert_issuer_name
        kind = var.cert_issuer_kind
      }
      dnsNames = var.gateway_dns_names
    }
  }
}

// Create default Gateway resource for HTTPS traffic
// Note: This requires Istio CRDs to be installed first.
// On first apply, the istio-base chart will install CRDs, so this will work.
resource "kubernetes_manifest" "default_gateway" {
  count      = var.create_default_gateway ? 1 : 0
  depends_on = [module.istio_base, module.istio_ingress, kubernetes_manifest.default_certificate]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "default-gateway"
      namespace = module.namespace.name
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
          tls = {
            httpsRedirect = true
          }
        },
        {
          port = {
            number   = 443
            name     = "https"
            protocol = "HTTPS"
          }
          hosts = ["*"]
          tls = {
            mode           = "SIMPLE"
            credentialName = var.default_tls_secret
          }
        }
      ]
    }
  }
}
