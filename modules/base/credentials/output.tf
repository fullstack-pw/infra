output "name" {
  description = "Name of the secret"
  value       = var.create_secret ? kubernetes_secret.this[0].metadata[0].name : ""
}

output "password" {
  description = "Generated or provided password"
  value       = local.password
  sensitive   = true
}

output "id" {
  description = "ID of the secret resource"
  value       = var.create_secret ? kubernetes_secret.this[0].id : ""
}

output "data" {
  description = "Data stored in the secret"
  value       = var.create_secret ? kubernetes_secret.this[0].data : {}
  sensitive   = true
}
