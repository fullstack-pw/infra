output "jaeger_ui_url" {
  value       = "https://jaeger.fullstack.pw"
  description = "URL for the Jaeger UI"
}

output "otel_collector_endpoint" {
  value       = "http://otel-collector.${var.namespace}.svc.cluster.local:4317"
  description = "OpenTelemetry Collector gRPC endpoint for telemetry ingestion"
}

output "otel_collector_http_endpoint" {
  value       = "http://otel-collector.${var.namespace}.svc.cluster.local:4318"
  description = "OpenTelemetry Collector HTTP endpoint for telemetry ingestion"
}