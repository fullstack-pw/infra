output "namespace" {
  description = "Namespace where MetalLB is deployed"
  value       = module.namespace.name
}

output "ip_pool_name" {
  description = "Name of the IPAddressPool"
  value       = var.create_ip_pool ? var.ip_pool_name : null
}
