output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.redis.name
}

output "namespace" {
  description = "Namespace of the deployed Redis"
  value       = helm_release.redis.namespace
}

output "redis_host" {
  description = "Redis service hostname"
  value       = "${var.release_name}-redis-master.${local.namespace}.svc.cluster.local"
}

output "redis_port" {
  description = "Redis service port"
  value       = var.service_port
}

output "redis_password" {
  description = "Redis password"
  value       = local.redis_password
  sensitive   = true
}

output "connection_string" {
  description = "Redis connection string"
  value       = "redis://:${local.redis_password}@${var.release_name}-redis-master.${local.namespace}.svc.cluster.local:${var.service_port}"
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing Redis credentials"
  value       = var.generate_password && var.create_credentials_secret ? kubernetes_secret.redis_credentials[0].metadata[0].name : null
}

output "metrics_enabled" {
  description = "Whether metrics are enabled for Redis"
  value       = var.enable_metrics
}

output "master_service_name" {
  description = "Name of the Redis master service"
  value       = "${var.release_name}-redis-master"
}

output "sentinel_enabled" {
  description = "Whether Redis Sentinel is enabled"
  value       = var.sentinel_enabled
}

output "sentinel_service_name" {
  description = "Name of the Redis Sentinel service (if Sentinel is enabled)"
  value       = var.sentinel_enabled ? "${var.release_name}-redis-headless" : null
}

output "sentinel_port" {
  description = "Redis Sentinel port (if Sentinel is enabled)"
  value       = var.sentinel_enabled ? 26379 : null
}

output "sentinel_connection_string" {
  description = "Redis Sentinel connection string (if Sentinel is enabled)"
  value       = var.sentinel_enabled ? "redis+sentinel://:${local.redis_password}@${var.release_name}-redis-headless.${local.namespace}.svc.cluster.local:26379/mymaster" : null
  sensitive   = true
}

output "ingress_host" {
  description = "Hostname for Redis ingress (if ingress is enabled)"
  value       = var.ingress_enabled ? var.ingress_host : null
}

output "ingress_enabled" {
  description = "Whether ingress is enabled for Redis"
  value       = var.ingress_enabled
}
