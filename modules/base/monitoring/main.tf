/**
 * Base Monitoring Module
 * 
 * This module provides standard monitoring configurations such as 
 * ServiceMonitor, PodMonitor, and PrometheusRule resources.
 */

resource "kubernetes_manifest" "service_monitor" {
  count = var.create_service_monitor ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels    = var.labels
    }
    spec = {
      selector = {
        matchLabels = var.selector_labels
      }
      endpoints = var.endpoints
    }
  }
}

resource "kubernetes_manifest" "pod_monitor" {
  count = var.create_pod_monitor ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels    = var.labels
    }
    spec = {
      selector = {
        matchLabels = var.selector_labels
      }
      podMetricsEndpoints = var.pod_metrics_endpoints
    }
  }
}

resource "kubernetes_manifest" "prometheus_rule" {
  count = var.create_prometheus_rule ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels    = var.labels
    }
    spec = {
      groups = var.rule_groups
    }
  }
}
