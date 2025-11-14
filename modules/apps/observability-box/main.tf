module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "otel_collector_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/otel-collector.yaml.tpl"
      vars = {
        mode               = var.otel_collector_mode
        logs_collection    = var.otel_collector_logs_collection
        otlp_enabled       = var.otel_collector_otlp_enabled
        otlp_port          = var.otel_collector_otlp_port
        otlp_http_enabled  = var.otel_collector_otlp_http_enabled
        otlp_http_port     = var.otel_collector_otlp_http_port
        exporters_endpoint = var.otel_collector_exporters_endpoint
        memory_limit       = var.otel_collector_memory_limit
        cpu_limit          = var.otel_collector_cpu_limit
        memory_request     = var.otel_collector_memory_request
        cpu_request        = var.otel_collector_cpu_request
        tls_insecure       = var.otel_collector_tls_insecure
        log_level          = var.otel_collector_log_level
      }
    }
  ]
}

module "otel_collector_helm" {
  source = "../../base/helm"

  release_name     = var.otel_collector_release_name
  namespace        = module.namespace.name
  create_namespace = false
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  chart_version    = var.otel_collector_chart_version
  timeout          = var.otel_collector_timeout
  values_files     = module.otel_collector_values.rendered_values

  set_values = var.otel_collector_additional_set_values
}

module "fluent_helm" {
  source = "../../base/helm"

  release_name     = var.fluent_release_name
  namespace        = module.namespace.name
  create_namespace = false
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  chart_version    = var.fluent_chart_version
  force_update     = var.fluent_force_update
  timeout          = var.fluent_timeout
  values_files     = module.fluent_values.rendered_values

  set_values = var.fluent_additional_set_values
}

module "fluent_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/fluent.yaml.tpl"
      vars = {
        CLUSTER = terraform.workspace
      }
    }
  ]
}

resource "kubectl_manifest" "prometheus_namespace_role" {
  for_each = length(var.prometheus_namespaces) > 0 ? toset(var.prometheus_namespaces) : toset([])

  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata = {
      name      = "prometheus-server"
      namespace = each.value
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["services", "endpoints", "pods", "configmaps"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["discovery.k8s.io"]
        resources = ["endpointslices"]
        verbs     = ["get", "list", "watch"]
      }
    ]
  })

  wait              = false
  server_side_apply = true

  depends_on = [module.namespace]
}

resource "kubectl_manifest" "prometheus_namespace_rolebinding" {
  for_each = length(var.prometheus_namespaces) > 0 ? toset(var.prometheus_namespaces) : toset([])

  yaml_body = yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "prometheus-server"
      namespace = each.value
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "prometheus-server"
    }
    subjects = [{
      kind      = "ServiceAccount"
      name      = "prometheus-server"
      namespace = module.namespace.name
    }]
  })

  wait              = false
  server_side_apply = true

  depends_on = [kubectl_manifest.prometheus_namespace_role]
}

module "prometheus_helm" {
  source = "../../base/helm"

  release_name     = var.prometheus_release_name
  namespace        = module.namespace.name
  create_namespace = false
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  chart_version    = var.prometheus_chart_version
  force_update     = var.prometheus_force_update
  timeout          = var.prometheus_timeout
  values_files     = module.prometheus_values.rendered_values

  set_values = var.prometheus_additional_set_values

  depends_on = [kubectl_manifest.prometheus_namespace_rolebinding]
}

module "prometheus_values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/prometheus.yaml.tpl"
      vars = {
        memory_limit     = var.prometheus_memory_limit
        cpu_limit        = var.prometheus_cpu_limit
        memory_request   = var.prometheus_memory_request
        cpu_request      = var.prometheus_cpu_request
        remote_write_url = var.prometheus_remote_write_url
        cluster_name     = terraform.workspace
        namespaces       = var.prometheus_namespaces
      }
    }
  ]
}
