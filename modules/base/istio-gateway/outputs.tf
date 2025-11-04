output "name" {
  description = "Name of the gateway"
  value       = var.enabled ? var.name : ""
}

output "namespace" {
  description = "Namespace of the gateway"
  value       = var.enabled ? var.namespace : ""
}

output "hosts" {
  description = "Hosts configured on the gateway"
  value       = var.enabled ? var.hosts : []
}
