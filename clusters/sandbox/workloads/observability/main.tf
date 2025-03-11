resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
  }
}

# Deploy OpenTelemetry Operator
resource "helm_release" "opentelemetry_operator" {
  name       = "opentelemetry-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [<<EOF
admissionWebhooks:
  enabled: true
certManager:
  enabled: true
EOF
  ]
}

# Deploy Jaeger Operator
resource "helm_release" "jaeger_operator" {
  name       = "jaeger-operator"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger-operator"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [<<EOF
rbac:
  clusterRole: true
EOF
  ]
}

# Deploy Jaeger instance
resource "kubernetes_manifest" "jaeger_instance" {
  manifest = yamldecode(file("${path.module}/manifests/jaeger-instance.yaml"))
  depends_on = [helm_release.jaeger_operator]
}

# Deploy OpenTelemetry Collector
resource "kubernetes_manifest" "otel_collector" {
  manifest = yamldecode(file("${path.module}/manifests/otel-collector-config.yaml"))
  depends_on = [helm_release.opentelemetry_operator]
}

# Deploy OpenTelemetry Collector Ingress
resource "kubernetes_manifest" "otel_collector_ingress" {
  manifest = yamldecode(file("${path.module}/manifests/otel-ingress.yaml"))
  depends_on = [helm_release.opentelemetry_operator]
}

# Create Ingress for Jaeger UI
resource "kubernetes_ingress_v1" "jaeger_ingress" {
  metadata {
    name      = "jaeger-ingress"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
      "external-dns.alpha.kubernetes.io/hostname" = "jaeger.fullstack.pw"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"
    
    tls {
      hosts       = ["jaeger.fullstack.pw"]
      secret_name = "jaeger-tls"
    }

    rule {
      host = "jaeger.fullstack.pw"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "jaeger-query"
              port {
                number = 16686
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.jaeger_instance]
}