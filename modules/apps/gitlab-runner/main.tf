/**
 * GitLab Runner Module
 * 
 * This module deploys GitLab Runner using our base modules for standardization.
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

module "credentials" {
  source = "../../base/credentials"

  name              = "gitlab-credentials"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = false # Set to false initially to avoid conflict with moved blocks

  data = {
    GITLAB_TOKEN = data.vault_kv_secret_v2.gitlab_runner_token.data["GITLAB_TOKEN"]
  }
}

module "kubeconfig_secret" {
  source = "../../base/credentials"

  name              = "kubeconfig"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = true # Keep this true as it matches the original resource

  data = {
    KUBECONFIG = data.vault_kv_secret_v2.gitlab_runner_token.data["KUBECONFIG"]
  }
}

data "vault_kv_secret_v2" "gitlab_runner_token" {
  mount = "kv"
  name  = "gitlab-runner"
}

resource "kubernetes_service_account" "gitlab_runner" {
  metadata {
    name      = var.service_account_name
    namespace = module.namespace.name
  }
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        service_account_name = kubernetes_service_account.gitlab_runner.metadata[0].name
        namespace            = module.namespace.name
        registration_token   = data.vault_kv_secret_v2.gitlab_runner_token.data["GITLAB_TOKEN"]
        concurrent           = var.concurrent_runners
        check_interval       = var.check_interval
        runner_tags          = var.runner_tags
        gitlab_url           = var.gitlab_url
        privileged           = var.privileged
        poll_timeout         = var.poll_timeout
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "gitlab-runner"
  repository       = "https://charts.gitlab.io"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values
}
