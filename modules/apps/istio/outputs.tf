output "namespace" {
  description = "Istio system namespace"
  value       = module.namespace.name
}

output "istio_version" {
  description = "Installed Istio version"
  value       = var.istio_version
}

output "gateway_service_name" {
  description = "Istio ingress gateway service name"
  value       = "istio-ingressgateway"
}

output "default_gateway_name" {
  description = "Default gateway resource name"
  value       = var.istio_CRDs ? "default-gateway" : ""
}
