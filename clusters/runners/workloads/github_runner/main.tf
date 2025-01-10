data "vault_kv_secret_v2" "github_token" {
  mount = "kv"
  name  = "github-runner"
}

resource "kubernetes_namespace" "arc_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "kubeconfig" {
  metadata {
    name      = "kubeconfig"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }

  data = {
    KUBECONFIG = data.vault_kv_secret_v2.github_token.data["KUBECONFIG"]
  }
}

resource "kubernetes_secret" "github_pat" {
  metadata {
    name      = "github-pat"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }

  data = {
    GITHUB_PAT = data.vault_kv_secret_v2.github_token.data["GITHUB_PAT"]
  }
}

# Create a Kubernetes Service Account
resource "kubernetes_service_account" "github_runner" {
  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }
}

# Vault Role for github Runner
# resource "vault_kubernetes_auth_backend_role" "github_runner" {
#   backend                          = "kubernetes"
#   role_name                        = "github-role"
#   token_policies                   = [vault_policy.github_secrets.name]
#   bound_service_account_names      = [kubernetes_service_account.github_runner.metadata[0].name]
#   bound_service_account_namespaces = [kubernetes_namespace.arc_namespace.metadata[0].name]
# }


# resource "vault_policy" "github_secrets" {
#   name = "github-secrets"

#   policy = <<EOT
#   path "kv/data/dummy-test" {
#     capabilities = ["read"]
#   }
#   path "kv/data/github-runner" {
#     capabilities = ["read"]
#   }
#   path "kv/data/k8s" {
#     capabilities = ["read"]
#   }
#   EOT
# }

# Deploy the GitHub Actions runner pod
resource "helm_release" "arc" {
  name       = "actions-runner-controller"
  namespace  = kubernetes_namespace.arc_namespace.metadata[0].name
  chart      = "actions-runner-controller"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  version    = "0.23.7"

  set {
    name  = "authSecret.create"
    value = true
  }

  set {
    name  = "authSecret.github_token"
    value = data.vault_kv_secret_v2.github_token.data["GITHUB_PAT"]
  }

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name = "certManagerEnabled"
    value = "false"
  }
  set {
    name = "image.actionsRunnerRepositoryAndTag"
    value = "registry.fullstack.pw/github-runner:latest"
  }
}

resource "kubernetes_manifest" "runner_deployment" {
  manifest = yamldecode(templatefile("${path.module}/runner_deployment.yaml.tpl", {
    github_owner = var.github_owner,
  }))
  depends_on = [helm_release.arc]
}

# resource "kubernetes_manifest" "runner_autoscaler" {
#   manifest = yamldecode(templatefile("${path.module}/runner_autoscaler.yaml.tpl", {
#     github_owner = var.github_owner,
#   }))
#   depends_on = [helm_release.arc]
# }

