data "vault_kv_secret_v2" "gitlab_runner_token" {
  mount = "kv"
  name  = "gitlab-runner"
}

resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "gitlab_runner" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
}

resource "kubernetes_secret" "kubeconfig" {
  metadata {
    name      = "kubeconfig"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    KUBECONFIG = data.vault_kv_secret_v2.gitlab_runner_token.data["KUBECONFIG"]
  }
}

resource "helm_release" "gitlab_runner" {
  name       = var.release_name
  namespace  = kubernetes_namespace.gitlab.metadata[0].name
  chart      = "gitlab-runner"
  repository = "https://charts.gitlab.io"
  version    = var.chart_version
  timeout    = var.timeout

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      service_account_name = kubernetes_service_account.gitlab_runner.metadata[0].name
      namespace            = kubernetes_namespace.gitlab.metadata[0].name
      registration_token   = data.vault_kv_secret_v2.gitlab_runner_token.data["GITLAB_TOKEN"]
      concurrent           = var.concurrent_runners
      check_interval       = var.check_interval
      runner_tags          = var.runner_tags
      gitlab_url           = var.gitlab_url
      privileged           = var.privileged
      poll_timeout         = var.poll_timeout
    })
  ]
}
