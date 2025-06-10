output "namespace" {
  description = "Namespace where KubeVirt is deployed"
  value       = var.namespace
}

output "kubevirt_cr_created" {
  description = "Whether the KubeVirt CR was created"
  value       = var.create_kubevirt_cr
}

output "cdi_cr_created" {
  description = "Whether the CDI CR was created"
  value       = var.create_cdi_cr
}

output "kubevirt_feature_gates" {
  description = "Enabled KubeVirt feature gates"
  value       = var.kubevirt_feature_gates
}

output "cdi_feature_gates" {
  description = "Enabled CDI feature gates"
  value       = var.cdi_feature_gates
}

output "cdi_uploadproxy_url" {
  description = "URL for CDI upload proxy (if ingress is enabled)"
  value       = var.enable_cdi_uploadproxy_ingress ? "https://${var.cdi_uploadproxy_host}" : null
}
