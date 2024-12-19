data "vault_generic_secret" "gitlab_runner_token" {
  path = "kv/gitlab-runner"
}

# Kubernetes Namespace for GitLab Runner
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

# Kubernetes Service Account for GitLab Runner
resource "kubernetes_service_account" "gitlab_runner" {
  metadata {
    name      = "gitlab-runner-sa"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
    annotations = {
      "vault.hashicorp.com/agent-inject"                   = "true"
      "vault.hashicorp.com/role"                           = "gitlab-role"
      "vault.hashicorp.com/agent-inject-secret-dummy-test" = "kv/data/dummy-test"
    }
  }
}

# Vault Role for GitLab Runner
resource "vault_kubernetes_auth_backend_role" "gitlab_runner" {
  backend                          = "kubernetes"
  role_name                        = "gitlab-role"
  token_policies                   = [vault_policy.gitlab_secrets.name]
  bound_service_account_names      = [kubernetes_service_account.gitlab_runner.metadata[0].name]
  bound_service_account_namespaces = [kubernetes_namespace.gitlab.metadata[0].name]
}


resource "vault_policy" "gitlab_secrets" {
  name = "gitlab-secrets"

  policy = <<EOT
  path "kv/data/dummy-test" {
    capabilities = ["read"]
  }
  path "kv/data/gitlab-runner" {
    capabilities = ["read"]
  }
  EOT
}

# Helm Chart for GitLab Runner
resource "helm_release" "gitlab_runner" {
  name       = "gitlab-runner"
  namespace  = kubernetes_namespace.gitlab.metadata[0].name
  chart      = "gitlab-runner"
  repository = "https://charts.gitlab.io"
  version    = "0.71.0"

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      service_account_name = kubernetes_service_account.gitlab_runner.metadata[0].name
      namespace            = kubernetes_namespace.gitlab.metadata[0].name
      registration_token   = data.vault_generic_secret.gitlab_runner_token.data.token
    })
  ]
}



