module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

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

resource "kubernetes_manifest" "jaeger_instance" {
  count = var.install_crd ? 1 : 0
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
        enabled = false
      }
    }
  }

  field_manager {
    force_conflicts = true
  }
  depends_on = [module.jaeger_operator.name]
}

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

resource "kubernetes_manifest" "otel_collector" {
  count = var.install_crd ? 1 : 0
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
        cluster_name                = terraform.workspace
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
  timeout          = 300
  create_namespace = false
  values_files     = var.prometheus_values_file != "" ? [var.prometheus_values_file] : module.prometheus_values[0].rendered_values
}

module "loki_values" {
  count  = var.loki_enabled ? 1 : 0
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/loki-values.yaml.tpl"
      vars = {
        deployment_mode             = var.deployment_mode
        storage_type                = var.loki_storage_type
        filesystem_directory_key    = var.loki_storage_type == "filesystem" ? "filesystem" : "chunks_directory"
        retention_period            = var.loki_retention_period
        replicas                    = var.loki_replicas
        memory_request              = var.loki_memory_request
        cpu_request                 = var.loki_cpu_request
        memory_limit                = var.loki_memory_limit
        cpu_limit                   = var.loki_cpu_limit
        persistence_enabled         = var.loki_persistence_enabled
        persistence_size            = var.loki_persistence_size
        persistence_storage_class   = var.loki_persistence_storage_class
        service_monitor_enabled     = var.loki_service_monitor_enabled
        ingress_class_name          = var.ingress_class_name
        cert_manager_cluster_issuer = var.cert_manager_cluster_issuer
        loki_domain                 = var.loki_domain
        promtail_enabled            = var.promtail_enabled
      }
    }
  ]
}

module "loki" {
  count  = var.loki_enabled ? 1 : 0
  source = "../../base/helm"

  release_name     = "loki"
  namespace        = module.namespace.name
  chart            = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart_version    = var.loki_chart_version
  timeout          = 300
  create_namespace = false
  values_files     = module.loki_values[0].rendered_values
}

resource "kubernetes_config_map" "unified_dashboard" {
  count = var.prometheus_enabled && var.loki_enabled ? 1 : 0

  metadata {
    name      = "unified-observability-dashboard"
    namespace = module.namespace.name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "unified-observability.json" = file("${path.module}/templates/unified-observability-dashboard.json")
  }

  depends_on = [module.prometheus, module.loki]
}
