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
  install_crd    = var.config[terraform.workspace].cert_manager_crd
}

// External Secrets
module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/external-secrets"

  namespace     = "external-secrets"
  chart_version = "0.12.1"
  vault_token   = var.VAULT_TOKEN
  vault_addr    = var.vault_addr
  install_crd   = var.config[terraform.workspace].install_crd

  namespace_selectors = {
    "kubernetes.io/metadata.name" = var.config[terraform.workspace].externalsecret
  }
}

// OpenTelemetry Collector
module "otel_collector" {
  count  = contains(local.workload, "otel_collector") ? 1 : 0
  source = "../modules/apps/otel-collector"

  namespace          = "observability"
  create_namespace   = true
  release_name       = "opentelemetry-collector"
  chart_version      = "0.62.0"
  mode               = "deployment"
  logs_collection    = false
  otlp_enabled       = true
  otlp_port          = 4317
  otlp_http_enabled  = true
  otlp_http_port     = 4318
  exporters_endpoint = "https://otel-collector.fullstack.pw"
  tls_insecure       = false
  log_level          = "debug"
  memory_limit       = "256Mi"
  cpu_limit          = "200m"
  memory_request     = "128Mi"
  cpu_request        = "100m"
  ingress_enabled    = false
}

module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/apps/github-runner"

  namespace          = "actions-runner-system"
  github_owner       = "fullstack-pw"
  arc_chart_version  = "0.23.7"
  runner_image       = "registry.fullstack.pw/github-runner:latest"
  runner_replicas    = 2
  enable_autoscaling = false
  github_token       = data.vault_kv_secret_v2.github_token[0].data["GITHUB_PAT"]
  install_crd        = var.config[terraform.workspace].install_crd
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
  source = "../modules/apps/minio"

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

module "postgres" {
  count  = contains(local.workload, "postgres") ? 1 : 0
  source = "../modules/apps/postgres"

  namespace                 = "default"
  create_namespace          = false
  release_name              = "postgres"
  persistence_storage_class = "local-path"
  persistence_size          = "10Gi"
  enable_metrics            = false

  # Optional: Enable replication for high availability
  replication_enabled  = false
  replication_replicas = 1

  # Set resource limits based on your environment
  memory_request = "512Mi"
  cpu_request    = "250m"
  memory_limit   = "1Gi"
  cpu_limit      = "500m"
}

module "redis" {
  count  = contains(local.workload, "redis") ? 1 : 0
  source = "../modules/apps/redis"

  # Basic configuration
  namespace        = "default"
  create_namespace = false
  release_name     = "redis"

  # Resource settings
  memory_request = "512Mi"
  memory_limit   = "1Gi"
  cpu_request    = "200m"
  cpu_limit      = "500m"

  # Persistence
  persistence_enabled       = true
  persistence_storage_class = "local-path"
  persistence_size          = "10Gi"

  # Authentication
  generate_password = true
  auth_enabled      = true

  # High Availability settings
  sentinel_enabled = false
  replicas         = 1

  # Connectivity
  service_type    = "LoadBalancer"
  ingress_enabled = true
  ingress_host    = "redis.fullstack.pw"
  ingress_annotations = {
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/service-upstream"      = "true"
  }

  # Monitoring
  enable_metrics = false
}


module "nats" {
  count  = contains(local.workload, "nats") ? 1 : 0
  source = "../modules/apps/nats"

  namespace        = "default"
  create_namespace = false
  release_name     = "nats"

  # Authentication settings
  auth_enabled      = true
  generate_password = true

  # JetStream persistence
  jetstream_enabled         = true
  persistence_enabled       = true
  persistence_storage_class = "local-path"
  persistence_size          = "2Gi"

  # Resources
  replicas       = 3
  memory_request = "256Mi"
  cpu_request    = "100m"
  memory_limit   = "512Mi"
  cpu_limit      = "200m"

  service_type = "LoadBalancer"

  # Monitoring and metrics
  prometheus_enabled = false
  monitoring_enabled = true

  # Ingress configuration
  ingress_enabled    = true
  ingress_host       = "nats.fullstack.pw"
  ingress_class_name = "traefik"
  ingress_annotations = {
    "external-dns.alpha.kubernetes.io/hostname" = "nats.fullstack.pw"
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
    "kubernetes.io/ingress.class"               = "traefik"
  }

  additional_set_values = []
}
