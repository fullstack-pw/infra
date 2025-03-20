output "namespace" {
  description = "The namespace where the registry is deployed"
  value       = module.namespace.name
}

output "registry_service_name" {
  description = "Name of the registry service"
  value       = kubernetes_service.registry.metadata[0].name
}

output "registry_service_port" {
  description = "Port of the registry service"
  value       = kubernetes_service.registry.spec[0].port[0].port
}

output "registry_internal_endpoint" {
  description = "Internal endpoint for the registry (cluster-local)"
  value       = "${kubernetes_service.registry.metadata[0].name}.${module.namespace.name}.svc.cluster.local:${kubernetes_service.registry.spec[0].port[0].port}"
}

output "registry_external_endpoint" {
  description = "External endpoint for the registry (if ingress is enabled)"
  value       = var.create_ingress ? "https://${var.ingress_host}" : null
}

output "pvc_name" {
  description = "Name of the persistent volume claim for registry storage"
  value       = module.persistence.name
}
