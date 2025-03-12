module "ingress_nginx" {
  count  = contains(local.workload, "ingress_nginx") ? 1 : 0
  source = "../modules/ingress-nginx"

  namespace          = "default"
  chart_version      = "1.2.0"
  enable_snippets    = true
  default_tls_secret = "default/fullstack-tls"
}

module "minio" {
  count  = contains(local.workload, "minio") ? 1 : 0
  source = "../modules/minio"

  namespace                 = "default"
  persistence_storage_class = "local-path"
  persistence_size          = "10Gi"
  ingress_host              = "s3.fullstack.pw"
  console_ingress_host      = "minio.fullstack.pw"
  ingress_annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = "s3.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
  console_ingress_annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = "minio.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
  }
}

module "registry" {
  count  = contains(local.workload, "registry") ? 1 : 0
  source = "../modules/registry"

  namespace    = "registry"
  storage_size = "10Gi"
  ingress_host = "registry.fullstack.pw"
}

module "vault" {
  count  = contains(local.workload, "vault") ? 1 : 0
  source = "../modules/vault"

  namespace          = "vault"
  ingress_host       = "vault.fullstack.pw"
  initialize_vault   = true
  kubernetes_ca_cert = var.kubernetes_ca_cert
  token_reviewer_jwt = var.token_reviewer_jwt
}

module "observability" {
  count  = contains(local.workload, "observability") ? 1 : 0
  source = "../modules/observability"

  namespace               = "observability"
  jaeger_storage_type     = "memory"
  otel_collector_replicas = 2
  jaeger_domain           = "jaeger.fullstack.pw"
  otel_collector_domain   = "otel-collector.fullstack.pw"
}

import {
  to = module.minio[0].helm_release.minio
  id = "default/minio"
}
import {
  to = module.observability[0].helm_release.jaeger_operator
  id = "observability/jaeger-operator"
}
import {
  to = module.observability[0].helm_release.opentelemetry_operator
  id = "observability/opentelemetry-operator"
}
import {
  to = module.observability[0].kubernetes_ingress_v1.jaeger_ingress
  id = "observability/jaeger-ingress"
}
import {
  to = module.observability[0].kubernetes_ingress_v1.otel_collector_ingress
  id = "observability/otel-collector-ingress"
}
import {
  to = module.observability[0].kubernetes_manifest.jaeger_instance
  id = "apiVersion=jaegertracing.io/v1,kind=Jaeger,namespace=observability,name=jaeger"
}
import {
  to = module.observability[0].kubernetes_manifest.otel_collector
  id = "apiVersion=opentelemetry.io/v1alpha1,kind=OpenTelemetryCollector,namespace=observability,name=otel-collector"
}
import {
  to = module.observability[0].kubernetes_namespace.observability
  id = "observability"
}
import {
  to = module.registry[0].kubernetes_deployment.registry
  id = "registry/registry"
}
import {
  to = module.registry[0].kubernetes_ingress_v1.registry_ingress[0]
  id = "registry/ingress-registry"
}
import {
  to = module.registry[0].kubernetes_namespace.registry[0]
  id = "registry"
}
import {
  to = module.registry[0].kubernetes_persistent_volume_claim.registry_storage
  id = "registry/registry-storage"
}
import {
  to = module.registry[0].kubernetes_service.registry
  id = "registry/registry"
}
import {
  to = module.vault[0].helm_release.vault
  id = "vault/vault"
}
import {
  to = module.vault[0].kubernetes_namespace.vault[0]
  id = "vault"
}
import {
  to = module.vault[0].vault_auth_backend.kubernetes[0]
  id = "kubernetes"
}
import {
  to = module.vault[0].vault_kubernetes_auth_backend_config.config[0]
  id = "auth/kubernetes/config"
}
import {
  to = module.vault[0].vault_mount.kv[0]
  id = "kv"
}
