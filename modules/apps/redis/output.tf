output "release_name" {
  description = "Name of the Helm release"
  value       = module.helm.name
}

output "namespace" {
  description = "Namespace of the deployed Redis"
  value       = module.namespace.name
}

output "redis_host" {
  description = "Redis service hostname"
  value       = "${var.release_name}-redis-master.${module.namespace.name}.svc.cluster.local"
}

output "redis_port" {
  description = "Redis service port"
  value       = var.service_port
}

output "redis_password" {
  description = "Redis password"
  value       = module.credentials.password
  sensitive   = true
}

output "connection_string" {
  description = "Redis connection string"
  value       = "redis://:${module.credentials.password}@${var.release_name}-redis-master.${module.namespace.name}.svc.cluster.local:${var.service_port}"
  sensitive   = true
}

output "credentials_secret_name" {
  description = "Name of the secret containing Redis credentials"
  value       = var.create_credentials_secret ? module.credentials.name : null
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
  value       = var.sentinel_enabled ? "redis+sentinel://:${module.credentials.password}@${var.release_name}-redis-headless.${module.namespace.name}.svc.cluster.local:26379/mymaster" : null
  sensitive   = true
}

output "ingress_host" {
  description = "Hostname for Redis ingress (if ingress is enabled)"
  value       = var.ingress_enabled ? module.ingress.host : null
}

output "ingress_url" {
  description = "URL for Redis ingress (if ingress is enabled)"
  value       = var.ingress_enabled ? module.ingress.url : null
}
