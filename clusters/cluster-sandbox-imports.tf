// MINIO
import {
  for_each = contains(local.workload, "minio") ? toset(["minio"]) : toset([])
  to       = module.minio[0].helm_release.minio
  id       = "default/minio"
}

// OBSERVABILITY
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].helm_release.jaeger_operator
  id       = "observability/jaeger-operator"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].helm_release.opentelemetry_operator
  id       = "observability/opentelemetry-operator"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].kubernetes_ingress_v1.jaeger_ingress
  id       = "observability/jaeger-ingress"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].kubernetes_ingress_v1.otel_collector_ingress
  id       = "observability/otel-collector-ingress"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].kubernetes_manifest.jaeger_instance
  id       = "apiVersion=jaegertracing.io/v1,kind=Jaeger,namespace=observability,name=jaeger"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].kubernetes_manifest.otel_collector
  id       = "apiVersion=opentelemetry.io/v1alpha1,kind=OpenTelemetryCollector,namespace=observability,name=otel-collector"
}
import {
  for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
  to       = module.observability[0].kubernetes_namespace.observability
  id       = "observability"
}

// REGISTRY
import {
  for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
  to       = module.registry[0].kubernetes_deployment.registry
  id       = "registry/registry"
}
import {
  for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
  to       = module.registry[0].kubernetes_ingress_v1.registry_ingress[0]
  id       = "registry/ingress-registry"
}
import {
  for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
  to       = module.registry[0].kubernetes_namespace.registry[0]
  id       = "registry"
}
import {
  for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
  to       = module.registry[0].kubernetes_persistent_volume_claim.registry_storage
  id       = "registry/registry-storage"
}
import {
  for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
  to       = module.registry[0].kubernetes_service.registry
  id       = "registry/registry"
}

// VAULT
import {
  for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
  to       = module.vault[0].helm_release.vault
  id       = "vault/vault"
}
import {
  for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
  to       = module.vault[0].kubernetes_namespace.vault[0]
  id       = "vault"
}
import {
  for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
  to       = module.vault[0].vault_auth_backend.kubernetes[0]
  id       = "kubernetes"
}
import {
  for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
  to       = module.vault[0].vault_kubernetes_auth_backend_config.config[0]
  id       = "auth/kubernetes/config"
}
import {
  for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
  to       = module.vault[0].vault_mount.kv[0]
  id       = "kv"
}
