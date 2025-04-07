module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"
}

module "cert_manager" {
  count  = contains(local.workload, "cert_manager") ? 1 : 0
  source = "../modules/apps/certmanager"

  install_crd       = var.config[terraform.workspace].cert_manager_crd
  cloudflare_secret = local.secrets_json["kv/cloudflare"]["api-token"]
}

module "external_secrets" {
  count  = contains(local.workload, "external_secrets") ? 1 : 0
  source = "../modules/apps/external-secrets"

  install_crd = var.config[terraform.workspace].install_crd

  namespace_selectors = {
    "kubernetes.io/metadata.name" = var.config[terraform.workspace].externalsecret
  }
}

module "otel_collector" {
  count  = contains(local.workload, "otel_collector") ? 1 : 0
  source = "../modules/apps/otel-collector"
}

module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/apps/github-runner"

  github_token = data.vault_kv_secret_v2.github_token[0].data["GITHUB_PAT"]
  install_crd  = var.config[terraform.workspace].install_crd
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/apps/gitlab-runner"
}

module "ingress_nginx" {
  count  = contains(local.workload, "ingress_nginx") ? 1 : 0
  source = "../modules/apps/ingress-nginx"

}

module "minio" {
  count  = contains(local.workload, "minio") ? 1 : 0
  source = "../modules/apps/minio"

  root_password = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
}

module "registry" {
  count  = contains(local.workload, "registry") ? 1 : 0
  source = "../modules/apps/registry"

}

module "vault" {
  count           = contains(local.workload, "vault") ? 1 : 0
  source          = "../modules/apps/vault"
  initial_secrets = local.vault_secrets
}

locals {
  secrets_json  = jsondecode(file("${path.module}/tmp/secrets.json"))
  vault_secrets = local.secrets_json
}

module "observability" {
  count  = contains(local.workload, "observability") ? 1 : 0
  source = "../modules/apps/observability"

  minio_rootPassword = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
}

module "postgres" {
  count  = contains(local.workload, "postgres") ? 1 : 0
  source = "../modules/apps/postgres"

  memory_request = "512Mi"
  cpu_request    = "250m"
  memory_limit   = "1Gi"
  cpu_limit      = "500m"
}

module "redis" {
  count  = contains(local.workload, "redis") ? 1 : 0
  source = "../modules/apps/redis"

}


module "nats" {
  count  = contains(local.workload, "nats") ? 1 : 0
  source = "../modules/apps/nats"

}

module "fluent" {
  count  = contains(local.workload, "fluent") ? 1 : 0
  source = "../modules/apps/fluent"

}
