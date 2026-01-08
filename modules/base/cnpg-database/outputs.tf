output "name" {
  description = "Kubernetes object name of the Database resource"
  value       = var.create ? kubernetes_manifest.database[0].manifest.metadata.name : null
}

output "database_name" {
  description = "PostgreSQL database name"
  value       = var.database_name
}

output "owner" {
  description = "Owner role of the database"
  value       = var.owner
}

output "cluster_name" {
  description = "CNPG Cluster name"
  value       = var.cluster_name
}
