// ExternalDNS
import {
  for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
  to       = module.externaldns[0].kubernetes_cluster_role.externaldns
  id       = contains(local.workload, "externaldns") ? "external-dns" : 0
}

import {
  for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
  to       = module.externaldns[0].kubernetes_cluster_role_binding.externaldns
  id       = contains(local.workload, "externaldns") ? "external-dns-viewer" : 0
}

import {
  for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
  to       = module.externaldns[0].kubernetes_deployment.externaldns
  id       = contains(local.workload, "externaldns") ? "default/external-dns" : 0
}

import {
  for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
  to       = module.externaldns[0].kubernetes_service_account.externaldns
  id       = contains(local.workload, "externaldns") ? "default/external-dns" : 0
}

// CertManager
import {
  for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
  to       = module.cert_manager[0].helm_release.cert_manager
  id       = "cert-manager/cert-manager"
}
import {
  for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
  to       = module.cert_manager[0].kubernetes_manifest.letsencrypt_issuer
  id       = "apiVersion=cert-manager.io/v1,kind=ClusterIssuer,namespace=cert-manager,name=letsencrypt-prod"
}
import {
  for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
  to       = module.cert_manager[0].kubernetes_namespace.cert_manager
  id       = "cert-manager"
}
import {
  for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
  to       = module.cert_manager[0].kubernetes_secret.cloudflare_api_token
  id       = "cert-manager/cloudflare-api-token"
}

// External Secrets
import {
  for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
  to       = module.external_secrets[0].kubernetes_namespace.external_secrets
  id       = "external-secrets"
}
import {
  for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
  to       = module.external_secrets[0].helm_release.external_secrets
  id       = "external-secrets/external-secrets"
}
import {
  for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
  to       = module.external_secrets[0].kubernetes_manifest.cluster_secrets
  id       = "apiVersion=external-secrets.io/v1beta1,kind=ClusterExternalSecret,name=cluster-secrets"
}
import {
  for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
  to       = module.external_secrets[0].kubernetes_manifest.vault_secret_store
  id       = "apiVersion=external-secrets.io/v1beta1,kind=ClusterSecretStore,name=vault-backend"
}
import {
  for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
  to       = module.external_secrets[0].kubernetes_secret.vault_token
  id       = "external-secrets/vault-token"
}

// OpenTelemetry Collector
import {
  for_each = contains(local.workload, "otel_collector") ? toset(["otel-collector"]) : toset([])
  to       = kubernetes_namespace.observability[0]
  id       = "observability"
}
import {
  for_each = contains(local.workload, "otel_collector") ? toset(["otel-collector"]) : toset([])
  to       = helm_release.opentelemetry_collector[0]
  id       = "observability/opentelemetry-collector"
}
