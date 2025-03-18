output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.nats.name
}

output "namespace" {
  description = "Namespace of the deployed NATS"
  value       = helm_release.nats.namespace
}

output "version" {
  description = "Version of the deployed NATS chart"
  value       = var.chart_version
}

output "service_name" {
  description = "Name of the NATS service"
  value       = "nats"
}

output "service_port" {
  description = "Port of the NATS service"
  value       = var.nats_port
}

output "nats_url" {
  description = "URL for connecting to NATS"
  value       = "nats://nats.${local.namespace}.svc.cluster.local:${var.nats_port}"
}

output "websocket_url" {
  description = "WebSocket URL for connecting to NATS (if enabled)"
  value       = var.websocket_enabled ? "ws://nats.${local.namespace}.svc.cluster.local:${var.websocket_port}" : null
}

output "monitoring_url" {
  description = "Monitoring URL for NATS (if enabled)"
  value       = var.monitoring_enabled ? "http://nats.${local.namespace}.svc.cluster.local:8222" : null
}

output "prometheus_url" {
  description = "Prometheus metrics URL (if enabled)"
  value       = var.prometheus_enabled ? "http://nats.${local.namespace}.svc.cluster.local:${var.prometheus_port}" : null
}

output "ingress_host" {
  description = "Hostname for NATS monitoring ingress (if enabled)"
  value       = var.ingress_enabled && var.monitoring_enabled ? var.ingress_host : null
}

output "credentials_secret_name" {
  description = "Name of the secret containing NATS credentials (if created)"
  value       = (var.auth_enabled || var.auth_token_enabled) && var.create_credentials_secret ? kubernetes_secret.nats_credentials[0].metadata[0].name : null
}

output "jetstream_enabled" {
  description = "Whether JetStream is enabled"
  value       = var.jetstream_enabled
}

output "auth_enabled" {
  description = "Whether authentication is enabled"
  value       = var.auth_enabled || var.auth_token_enabled
}
