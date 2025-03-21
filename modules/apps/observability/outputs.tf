output "namespace" {
  description = "Namespace where the observability stack is deployed"
  value       = module.namespace.name
}

output "jaeger_ui_url" {
  description = "URL for the Jaeger UI"
  value       = "https://${var.jaeger_domain}"
}

output "otel_collector_endpoint" {
  description = "OpenTelemetry Collector gRPC endpoint for telemetry ingestion"
  value       = "http://${var.otel_collector_name}.${module.namespace.name}.svc.cluster.local:4317"
}

output "otel_collector_http_endpoint" {
  description = "OpenTelemetry Collector HTTP endpoint for telemetry ingestion"
  value       = "http://${var.otel_collector_name}.${module.namespace.name}.svc.cluster.local:4318"
}

output "otel_collector_external_endpoint" {
  description = "External OpenTelemetry Collector endpoint"
  value       = "https://${var.otel_collector_domain}"
}

output "jaeger_collector_endpoint" {
  description = "Jaeger Collector endpoint for direct trace submission"
  value       = "${var.jaeger_instance_name}-collector.${module.namespace.name}.svc.cluster.local:14268"
}

output "prometheus_url" {
  description = "URL for the Prometheus UI"
  value       = var.prometheus_enabled ? "https://${var.prometheus_domain}" : null
}

output "grafana_url" {
  description = "URL for the Grafana UI"
  value       = var.prometheus_enabled ? "https://${var.grafana_domain}" : null
}

output "loki_url" {
  description = "URL for the Loki UI"
  value       = var.loki_enabled ? "https://${var.loki_domain}" : null
}

output "loki_endpoint" {
  description = "Internal Loki endpoint for log pushing"
  value       = var.loki_enabled ? "http://loki-gateway.${module.namespace.name}.svc.cluster.local:3100" : null
}

output "promtail_enabled" {
  description = "Whether Promtail is enabled for log collection"
  value       = var.loki_enabled && var.promtail_enabled
}

output "logs_available" {
  description = "Whether logs are available in the observability stack"
  value       = var.loki_enabled
}
