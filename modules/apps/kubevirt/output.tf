output "namespace" {
  description = "Namespace where KubeVirt is installed"
  value       = module.namespace.name
}

output "version" {
  description = "Installed KubeVirt version"
  value       = local.kubevirt_version
}

output "operator_url" {
  description = "URL of the KubeVirt operator manifest"
  value       = local.operator_url
}

output "cr_url" {
  description = "URL of the KubeVirt CR manifest"
  value       = local.cr_url
}
