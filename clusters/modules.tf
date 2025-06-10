module "externaldns" {
  count  = contains(local.workload, "externaldns") ? 1 : 0
  source = "../modules/apps/externaldns"

  create_pihole_secret = terraform.workspace == "sandbox" ? true : false
  pihole_password      = terraform.workspace == "sandbox" ? local.secrets_json["kv/cluster-secret-store/secrets/EXTERNAL_DNS_PIHOLE_PASSWORD"]["PIHOLE_PASSWORD"] : ""

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
  secret_data = local.secret_data
  vault_token = local.secrets_json["kv/cluster-secret-store/secrets/VAULT_TOKEN"]["VAULT_TOKEN"]

  namespace_selector_type = "label"
  namespace_selector_label = {
    key   = "cluster-secrets"
    value = "true"
  }
}


module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/apps/github-runner"

  github_token = local.secrets_json["kv/cluster-secret-store/secrets/github_token"]["github_token"]
  install_crd  = var.config[terraform.workspace].install_crd
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/apps/gitlab-runner"

  gitlab_token = local.secrets_json["kv/cluster-secret-store/secrets/GITLAB_TOKEN"]["GITLAB_TOKEN"]
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

module "observability" {
  count  = contains(local.workload, "observability") ? 1 : 0
  source = "../modules/apps/observability"

  minio_rootPassword = local.secrets_json["kv/cluster-secret-store/secrets/MINIO"]["rootPassword"]
}

module "observability-box" {
  count  = contains(local.workload, "observability-box") ? 1 : 0
  source = "../modules/apps/observability-box"
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

module "harbor" {
  count  = contains(local.workload, "harbor") ? 1 : 0
  source = "../modules/apps/harbor"

  external_database_password = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  external_redis_password    = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
}

module "immich" {
  count  = contains(local.workload, "immich") ? 1 : 0
  source = "../modules/apps/immich"

  redis         = "redis.fullstack.pw"
  redis_pass    = local.secrets_json["kv/cluster-secret-store/secrets/REDIS"]["REDIS_PASSWORD"]
  db_hostname   = "postgres.fullstack.pw"
  db_user       = "admin"
  db_name       = "immich"
  db_pass       = local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"]
  immich_domain = "immich.fullstack.pw"

}

module "kubevirt" {
  count  = contains(local.workload, "kubevirt") ? 1 : 0
  source = "../modules/apps/kubevirt"
}

module "longhorn" {
  count  = contains(local.workload, "longhorn") ? 1 : 0
  source = "../modules/apps/longhorn"

  replica_count = 1 # Single node cluster
  ingress_host  = "longhorn.fullstack.pw"
}
