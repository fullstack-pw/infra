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
