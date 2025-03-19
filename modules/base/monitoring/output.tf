output "service_monitor_name" {
  description = "Name of the created ServiceMonitor"
  value       = var.create_service_monitor ? kubernetes_manifest.service_monitor[0].manifest.metadata.name : ""
}

output "pod_monitor_name" {
  description = "Name of the created PodMonitor"
  value       = var.create_pod_monitor ? kubernetes_manifest.pod_monitor[0].manifest.metadata.name : ""
}

output "prometheus_rule_name" {
  description = "Name of the created PrometheusRule"
  value       = var.create_prometheus_rule ? kubernetes_manifest.prometheus_rule[0].manifest.metadata.name : ""
}
