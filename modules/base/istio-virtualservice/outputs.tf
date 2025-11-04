output "name" {
  description = "Name of the VirtualService"
  value       = var.enabled ? var.name : ""
}

output "namespace" {
  description = "Namespace of the VirtualService"
  value       = var.enabled ? var.namespace : ""
}

output "hosts" {
  description = "Hosts configured on the VirtualService"
  value       = var.enabled ? var.hosts : []
}
