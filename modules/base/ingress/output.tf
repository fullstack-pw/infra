output "name" {
  description = "Name of the ingress"
  value       = var.enabled ? kubernetes_ingress_v1.this[0].metadata[0].name : ""
}

output "host" {
  description = "Hostname for the ingress"
  value       = var.host
}

output "url" {
  description = "URL for the ingress"
  value       = var.enabled ? "https://${var.host}" : ""
}

output "id" {
  description = "ID of the ingress resource"
  value       = var.enabled ? kubernetes_ingress_v1.this[0].id : ""
}
