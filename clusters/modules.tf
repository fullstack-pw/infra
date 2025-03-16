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

// CertManager
module "cert_manager" {
  count  = contains(local.workload, "cert_manager") ? 1 : 0
  source = "../modules/certmanager"

  namespace      = "cert-manager"
  chart_version  = "v1.16.2"
  vault_token    = var.VAULT_TOKEN
  cluster_issuer = "letsencrypt-prod"
  email          = "pedropilla@gmail.com"
}

// External Secrets
module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/external-secrets"

  namespace     = "external-secrets"
  chart_version = "0.12.1"
  vault_token   = var.VAULT_TOKEN
  vault_addr    = var.vault_addr

  namespace_selectors = {
    "kubernetes.io/metadata.name" = var.config[terraform.workspace].externalsecret
  }
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
    otlphttp/sandbox:
      endpoint: "https://otel-collector.fullstack.pw"
      tls:
        insecure: false
    logging:
      loglevel: debug

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlphttp/sandbox, logging]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlphttp/sandbox, logging]

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

module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/github-runner"

  namespace          = "actions-runner-system"
  github_owner       = "fullstack-pw"
  arc_chart_version  = "0.23.7"
  runner_image       = "registry.fullstack.pw/github-runner:latest"
  runner_replicas    = 2
  enable_autoscaling = false
  github_token       = data.vault_kv_secret_v2.github_token[0].data["GITHUB_PAT"]
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/gitlab-runner"

  namespace            = "gitlab"
  service_account_name = "gitlab-runner-sa"
  release_name         = "gitlab-runner"
  chart_version        = "0.71.0"
  concurrent_runners   = 10
  runner_tags          = "k8s-gitlab-runner"
}

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
  prometheus_enabled      = true
  prometheus_domain       = "prometheus.fullstack.pw"
  grafana_domain          = "grafana.fullstack.pw"
}
