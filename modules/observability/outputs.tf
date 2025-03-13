output "namespace" {
  description = "Namespace where the observability stack is deployed"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "jaeger_ui_url" {
  description = "URL for the Jaeger UI"
  value       = "https://${var.jaeger_domain}"
}

output "otel_collector_endpoint" {
  description = "OpenTelemetry Collector gRPC endpoint for telemetry ingestion"
  value       = "http://${var.otel_collector_name}.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4317"
}

output "otel_collector_http_endpoint" {
  description = "OpenTelemetry Collector HTTP endpoint for telemetry ingestion"
  value       = "http://${var.otel_collector_name}.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:4318"
}

output "otel_collector_external_endpoint" {
  description = "External OpenTelemetry Collector endpoint"
  value       = "https://${var.otel_collector_domain}"
}

output "jaeger_collector_endpoint" {
  description = "Jaeger Collector endpoint for direct trace submission"
  value       = "${var.jaeger_instance_name}-collector.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:14268"
}

output "prometheus_url" {
  description = "URL for the Prometheus UI"
  value       = var.prometheus_enabled ? "https://${var.prometheus_domain}" : null
}

output "grafana_url" {
  description = "URL for the Grafana UI"
  value       = var.prometheus_enabled ? "https://${var.grafana_domain}" : null
}
