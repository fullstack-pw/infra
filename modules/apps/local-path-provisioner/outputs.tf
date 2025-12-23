output "namespace" {
  description = "Namespace where local-path-provisioner is deployed"
  value       = module.namespace.name
}

output "storage_class_name" {
  description = "Name of the created storage class"
  value       = var.storage_class_name
}
