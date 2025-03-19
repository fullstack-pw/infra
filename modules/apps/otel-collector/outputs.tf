output "release_name" {
  description = "Name of the Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace of the deployed OpenTelemetry Collector"
  value       = module.namespace.name
}

output "version" {
  description = "Version of the deployed OpenTelemetry Collector chart"
  value       = var.chart_version
}

output "otlp_endpoint" {
  description = "OTLP/gRPC endpoint URL for sending telemetry"
  value       = "${var.release_name}-collector.${module.namespace.name}.svc.cluster.local:${var.otlp_port}"
}

output "otlp_http_endpoint" {
  description = "OTLP/HTTP endpoint URL for sending telemetry"
  value       = "${var.release_name}-collector.${module.namespace.name}.svc.cluster.local:${var.otlp_http_port}"
}

output "ingress_enabled" {
  description = "Whether ingress is enabled for the collector"
  value       = var.ingress_enabled
}

output "ingress_endpoint" {
  description = "Ingress endpoint URL (if enabled)"
  value       = var.ingress_enabled ? "https://${var.ingress_host}" : null
}

output "ingress_host" {
  description = "Hostname for the collector ingress (if enabled)"
  value       = var.ingress_enabled ? var.ingress_host : null
}
