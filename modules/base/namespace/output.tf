output "name" {
  description = "Name of the namespace"
  value       = local.namespace
}

output "labels" {
  description = "Labels applied to the namespace"
  value       = var.create ? kubernetes_namespace.this[0].metadata[0].labels : {}
}

output "id" {
  description = "ID of the namespace resource"
  value       = var.create ? kubernetes_namespace.this[0].id : ""
}
