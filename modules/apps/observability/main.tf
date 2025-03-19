/**
 * Observability Module
 * 
 * This module deploys a complete observability stack using our base modules for standardization.
 * It includes OpenTelemetry Operator, Jaeger, OpenTelemetry Collector, and optionally Prometheus/Grafana.
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

# Deploy OpenTelemetry Operator
module "otel_operator_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/otel-operator-values.yaml.tpl"
      vars = {
        admission_webhooks_enabled = var.admission_webhooks_enabled
        cert_manager_enabled       = var.cert_manager_enabled
      }
    }
  ]
}

module "otel_operator" {
  source = "../../base/helm"

  release_name     = "opentelemetry-operator"
  namespace        = module.namespace.name
  chart            = "opentelemetry-operator"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart_version    = var.opentelemetry_operator_version
  timeout          = 300
  create_namespace = false
  values_files     = module.otel_operator_values.rendered_values
}

# Deploy Jaeger Operator
module "jaeger_operator_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/jaeger-operator-values.yaml.tpl"
      vars = {
        rbac_cluster_role = var.jaeger_rbac_cluster_role
      }
    }
  ]
}

module "jaeger_operator" {
  source = "../../base/helm"

  release_name     = "jaeger-operator"
  namespace        = module.namespace.name
  chart            = "jaeger-operator"
  repository       = "https://jaegertracing.github.io/helm-charts"
  chart_version    = var.jaeger_operator_version
  timeout          = 300
  create_namespace = false
  values_files     = module.jaeger_operator_values.rendered_values
}

# Deploy Jaeger instance
resource "kubernetes_manifest" "jaeger_instance" {
  manifest = {
    apiVersion = "jaegertracing.io/v1"
    kind       = "Jaeger"
    metadata = {
      name      = var.jaeger_instance_name
      namespace = module.namespace.name
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
  depends_on = [module.jaeger_operator.name]
}

# Deploy OpenTelemetry Collector configuration
module "otel_collector_config" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/otel-collector-config.yaml.tpl"
      vars = {
        jaeger_endpoint = "${var.jaeger_instance_name}-collector.${module.namespace.name}.svc.cluster.local:4317"
      }
    }
  ]
}

# Deploy OpenTelemetry Collector
resource "kubernetes_manifest" "otel_collector" {
  manifest = {
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = var.otel_collector_name
      namespace = module.namespace.name
    }
    spec = {
      replicas = var.otel_collector_replicas
      config   = module.otel_collector_config.rendered_values[0]
    }
  }
  depends_on = [module.otel_operator.name]
}

# Create Ingress for Jaeger UI
module "jaeger_ingress" {
  source = "../../base/ingress"

  enabled            = true
  name               = "${var.jaeger_instance_name}-ingress"
  namespace          = module.namespace.name
  host               = var.jaeger_domain
  service_name       = "${var.jaeger_instance_name}-query"
  service_port       = 16686
  path               = "/"
  path_type          = "Prefix"
  tls_enabled        = true
  tls_secret_name    = "${var.jaeger_instance_name}-tls"
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations        = var.jaeger_ingress_annotations
}

# Create Ingress for OpenTelemetry Collector HTTP
module "otel_collector_http_ingress" {
  source = "../../base/ingress"

  enabled      = true
  name         = "${var.otel_collector_name}-http-ingress"
  namespace    = module.namespace.name
  host         = var.otel_collector_domain
  service_name = "${var.otel_collector_name}-collector"
  paths = [
    {
      path      = "/v1/traces"
      path_type = "Prefix"
      backend = {
        service_port_name = "otlp-http"
      }
    },
    {
      path      = "/v1/metrics"
      path_type = "Prefix"
      backend = {
        service_port_name = "otlp-http"
      }
    }
  ]
  tls_enabled        = true
  tls_secret_name    = "${var.otel_collector_name}-tls"
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations = {
    "nginx.ingress.kubernetes.io/ssl-redirect"  = "true",
    "external-dns.alpha.kubernetes.io/hostname" = var.otel_collector_domain
  }
}

# Deploy Prometheus stack if enabled
module "prometheus_values" {
  count  = var.prometheus_enabled ? 1 : 0
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/prometheus-values.yaml.tpl"
      vars = {
        prometheus_domain           = var.prometheus_domain
        grafana_domain              = var.grafana_domain
        ingress_class_name          = var.ingress_class_name
        cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
      }
    }
  ]
}

module "prometheus" {
  count  = var.prometheus_enabled ? 1 : 0
  source = "../../base/helm"

  release_name     = "prometheus"
  namespace        = module.namespace.name
  chart            = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart_version    = var.prometheus_chart_version
  timeout          = 900 # Increase timeout for complex installation
  create_namespace = false
  values_files     = var.prometheus_values_file != "" ? [var.prometheus_values_file] : module.prometheus_values[0].rendered_values
}
