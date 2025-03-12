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
  version    = var.opentelemetry_operator_version

  values = [
    templatefile("${path.module}/templates/otel-operator-values.yaml.tpl", {
      admission_webhooks_enabled = var.admission_webhooks_enabled
      cert_manager_enabled       = var.cert_manager_enabled
    })
  ]
}

# Deploy Jaeger Operator
resource "helm_release" "jaeger_operator" {
  name       = "jaeger-operator"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger-operator"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  version    = var.jaeger_operator_version

  values = [
    templatefile("${path.module}/templates/jaeger-operator-values.yaml.tpl", {
      rbac_cluster_role = var.jaeger_rbac_cluster_role
    })
  ]
}

# Deploy Jaeger instance
resource "kubernetes_manifest" "jaeger_instance" {
  manifest = {
    apiVersion = "jaegertracing.io/v1"
    kind       = "Jaeger"
    metadata = {
      name      = var.jaeger_instance_name
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      strategy = var.jaeger_storage_type == "memory" ? "allinone" : "production"
      storage = {
        type = var.jaeger_storage_type
      }
      ingress = {
        enabled = false # We'll create our own ingress
      }
    }
  }

  # Add field manager configuration to handle conflicts with Jaeger Operator
  field_manager {
    # Set force_conflicts to true to override conflicts with other controllers
    force_conflicts = true
  }
  depends_on = [helm_release.jaeger_operator]
}

# Deploy OpenTelemetry Collector
resource "kubernetes_manifest" "otel_collector" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = var.otel_collector_name
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      replicas = var.otel_collector_replicas
      config = templatefile("${path.module}/templates/otel-collector-config.yaml.tpl", {
        jaeger_endpoint = "${var.jaeger_instance_name}-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
      })
    }
  }
  depends_on = [helm_release.opentelemetry_operator]
}

# Create Ingress for OpenTelemetry Collector
resource "kubernetes_ingress_v1" "otel_collector_ingress" {
  metadata {
    name      = "${var.otel_collector_name}-ingress"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = merge({
      "nginx.ingress.kubernetes.io/ssl-redirect"  = "true"
      "external-dns.alpha.kubernetes.io/hostname" = var.otel_collector_domain
      "cert-manager.io/cluster-issuer"            = var.cert_manager_cluster_issuer
    }, var.otel_collector_ingress_annotations)
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.otel_collector_domain]
      secret_name = "${var.otel_collector_name}-tls"
    }

    rule {
      host = var.otel_collector_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.otel_collector_name
              port {
                number = 4317
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.otel_collector]
}

# Create Ingress for Jaeger UI
resource "kubernetes_ingress_v1" "jaeger_ingress" {
  metadata {
    name      = "${var.jaeger_instance_name}-ingress"
    namespace = kubernetes_namespace.observability.metadata[0].name
    annotations = merge({
      "nginx.ingress.kubernetes.io/ssl-redirect"    = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
      "external-dns.alpha.kubernetes.io/hostname"   = var.jaeger_domain
      "cert-manager.io/cluster-issuer"              = var.cert_manager_cluster_issuer
    }, var.jaeger_ingress_annotations)
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.jaeger_domain]
      secret_name = "${var.jaeger_instance_name}-tls"
    }

    rule {
      host = var.jaeger_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${var.jaeger_instance_name}-query"
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
