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
