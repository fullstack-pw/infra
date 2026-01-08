output "cluster_name" {
  description = "PostgreSQL cluster name"
  value       = var.cluster_name
}

output "namespace" {
  description = "Namespace where PostgreSQL cluster is deployed"
  value       = var.namespace
}

output "service_rw" {
  description = "Read-write service name"
  value       = "${var.cluster_name}-rw.${var.namespace}.svc.cluster.local"
}

output "service_ro" {
  description = "Read-only service name"
  value       = "${var.cluster_name}-ro.${var.namespace}.svc.cluster.local"
}

output "service_r" {
  description = "Read service name (any instance)"
  value       = "${var.cluster_name}-r.${var.namespace}.svc.cluster.local"
}

output "backup_username" {
  description = "Backup user username"
  value       = var.create_backup_user ? var.backup_username : null
}

output "superuser_secret_name" {
  description = "Name of the CNPG-managed superuser secret (when enable_superuser_access is true)"
  value       = var.enable_superuser_access ? "${var.cluster_name}-superuser" : null
}

output "app_secret_name" {
  description = "Name of the auto-generated app user secret (initdb owner)"
  value       = "${var.cluster_name}-app"
}

output "managed_role_secret_names" {
  description = "Map of managed role names to their expected secret names"
  value = {
    for role in var.managed_roles : role.name => role.password_secret_name != null ? role.password_secret_name : null
  }
}
