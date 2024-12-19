# Fetch the GitHub token from Vault
data "vault_kv_secret_v2" "github_token" {
  mount = "kv"            # Adjust to your Vault KV mount name
  name  = "github-runner" # Path to the secret in Vault
}

# data "http" "horizontalrunnerautoscaler" {
#   url = "https://raw.githubusercontent.com/actions/actions-runner-controller/master/charts/actions-runner-controller/crds/actions.summerwind.dev_horizontalrunnerautoscalers.yaml"
# }

# data "http" "runner" {
#   url = "https://raw.githubusercontent.com/actions/actions-runner-controller/master/charts/actions-runner-controller/crds/actions.summerwind.dev_runners.yaml"
# }

# data "http" "runnerdeployment" {
#   url = "https://raw.githubusercontent.com/actions/actions-runner-controller/master/charts/actions-runner-controller/crds/actions.summerwind.dev_runnerdeployments.yaml"
# }

# resource "kubernetes_manifest" "horizontalrunnerautoscaler" {
#   manifest = yamldecode(data.http.horizontalrunnerautoscaler.body)
# }

# resource "kubernetes_manifest" "runner" {
#   manifest = yamldecode(data.http.runner.body)
# }

# resource "kubernetes_manifest" "runnerdeployment" {
#   manifest = yamldecode(data.http.runnerdeployment.body)
# }


resource "kubernetes_namespace" "arc_namespace" {
  metadata {
    name = var.namespace
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
    annotations = {
      "vault.hashicorp.com/agent-inject"                   = "true"
      "vault.hashicorp.com/role"                           = "github-role"
      "vault.hashicorp.com/agent-inject-secret-dummy-test" = "kv/data/dummy-test"
    }
  }
}

# Vault Role for github Runner
resource "vault_kubernetes_auth_backend_role" "github_runner" {
  backend                          = "kubernetes"
  role_name                        = "github-role"
  token_policies                   = [vault_policy.github_secrets.name]
  bound_service_account_names      = [kubernetes_service_account.github_runner.metadata[0].name]
  bound_service_account_namespaces = [kubernetes_namespace.arc_namespace.metadata[0].name]
}


resource "vault_policy" "github_secrets" {
  name = "github-secrets"

  policy = <<EOT
  path "kv/data/dummy-test" {
    capabilities = ["read"]
  }
  path "kv/data/github-runner" {
    capabilities = ["read"]
  }
  EOT
}

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
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = "v1.16.2" # Adjust version if needed

  values = [
    <<-EOF
    installCRDs: true
    EOF
  ]

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_manifest" "runner_deployment" {
  manifest = yamldecode(templatefile("${path.module}/runner_deployment.yaml.tpl", {
    github_owner    = var.github_owner,
    runner_replicas = var.runner_replicas,
  }))
  depends_on = [helm_release.arc]
}

resource "kubernetes_manifest" "runner_autoscaler" {
  manifest = yamldecode(templatefile("${path.module}/runner_autoscaler.yaml.tpl", {
    github_owner = var.github_owner,
  }))
  depends_on = [helm_release.arc]
}
