output "namespace" {
  description = "Namespace where CloudNativePG operator is installed"
  value       = helm_release.cloudnative_pg.namespace
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.cloudnative_pg.name
}
