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
  vault_token    = var.vault_token
  cluster_issuer = "letsencrypt-prod"
  email          = "pedropilla@gmail.com"
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
