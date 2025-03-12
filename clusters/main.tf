// ExternalDNS
module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/externaldns"

  namespace          = "default"
  replicas           = 1
  pihole_secret_name = "pihole-password"

  container_args = [
    "--pihole-tls-skip-verify",
    "--source=ingress",
    "--registry=noop",
    "--policy=upsert-only",
    "--provider=pihole",
    "--pihole-server=http://192.168.1.3"
  ]
}

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
module "cert_manager" {
  count  = contains(local.workload, "cert_manager") ? 1 : 0
  source = "../modules/certmanager"

  namespace      = "cert-manager"
  chart_version  = "v1.16.2"
  vault_token    = var.vault_token
  cluster_issuer = "letsencrypt-prod"
  email          = "pedropilla@gmail.com"
}

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
module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/external-secrets"

  namespace     = "external-secrets"
  chart_version = "0.12.1"
  vault_token   = var.vault_token
  vault_addr    = var.vault_addr

  namespace_selectors = {
    "kubernetes.io/metadata.name" = "github-runner"
  }
}
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
resource "kubernetes_namespace" "observability" {
  count = contains(local.workload, "otel_collector") ? 1 : 0
  metadata {
    name = "observability"
  }
}

resource "helm_release" "opentelemetry_collector" {
  count      = contains(local.workload, "otel_collector") ? 1 : 0
  name       = "opentelemetry-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.observability[0].metadata[0].name
  version    = "0.62.0"

  values = [<<EOF
mode: deployment

presets:
  logsCollection:
    enabled: false

ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
    protocol: TCP
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    protocol: TCP

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
  
  processors:
    batch:
      timeout: 1s
      send_batch_size: 1024
    memory_limiter:
      check_interval: 1s
      limit_percentage: 80
      spike_limit_percentage: 25
  
  exporters:
    otlp:
      endpoint: "otel-collector.fullstack.pw:443"
      tls:
        insecure: false
    logging:
      loglevel: info
  
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp, logging]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp, logging]

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
EOF
  ]
}
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
