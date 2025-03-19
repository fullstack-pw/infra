output "name" {
  description = "Name of the PVC"
  value       = var.enabled ? kubernetes_persistent_volume_claim.this[0].metadata[0].name : ""
}

output "storage_class" {
  description = "Storage class of the PVC"
  value       = var.storage_class
}

output "size" {
  description = "Size of the PVC"
  value       = var.size
}

output "id" {
  description = "ID of the PVC resource"
  value       = var.enabled ? kubernetes_persistent_volume_claim.this[0].id : ""
}
