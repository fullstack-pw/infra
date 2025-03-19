/**
 * OpenTelemetry Collector Module
 * 
 * This module deploys the OpenTelemetry Collector using our base modules.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        mode               = var.mode
        logs_collection    = var.logs_collection
        otlp_enabled       = var.otlp_enabled
        otlp_port          = var.otlp_port
        otlp_http_enabled  = var.otlp_http_enabled
        otlp_http_port     = var.otlp_http_port
        exporters_endpoint = var.exporters_endpoint
        memory_limit       = var.memory_limit
        cpu_limit          = var.cpu_limit
        memory_request     = var.memory_request
        cpu_request        = var.cpu_request
        tls_insecure       = var.tls_insecure
        log_level          = var.log_level
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

module "ingress" {
  count  = var.ingress_enabled ? 1 : 0
  source = "../../base/ingress"

  enabled            = true
  name               = "${var.release_name}-ingress"
  namespace          = module.namespace.name
  host               = var.ingress_host
  service_name       = "${var.release_name}-collector"
  service_port       = var.otlp_http_port
  path               = "/"
  path_type          = "Prefix"
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  annotations        = var.ingress_annotations
}
