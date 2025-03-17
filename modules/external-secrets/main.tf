resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.namespace
  }
}
resource "helm_release" "external_secrets" {
  name         = "external-secrets"
  namespace    = kubernetes_namespace.external_secrets.metadata[0].name
  repository   = "https://charts.external-secrets.io"
  chart        = "external-secrets"
  version      = var.chart_version
  timeout      = var.timeout
  atomic       = true
  force_update = true

  values = [
    <<-EOF
    installCRDs: true
    EOF
  ]
}

// Create Secret for Vault token
resource "kubernetes_secret" "vault_token" {
  metadata {
    name      = "vault-token"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  data = {
    token = var.vault_token
  }
}

// Deploy ClusterSecretStore
resource "kubernetes_manifest" "vault_secret_store" {
  count = var.deploy_crd == true ? 1 : 0
  manifest = {
    "apiVersion" = "external-secrets.io/v1beta1"
    "kind"       = "ClusterSecretStore"
    "metadata" = {
      "name" = "vault-backend"
    }
    "spec" = {
      "provider" = {
        "vault" = {
          "server"  = var.vault_addr
          "path"    = var.vault_path
          "version" = "v1"
          "auth" = {
            "tokenSecretRef" = {
              "name"      = "vault-token"
              "namespace" = kubernetes_namespace.external_secrets.metadata[0].name
              "key"       = "token"
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

// Deploy ClusterExternalSecret
resource "kubernetes_manifest" "cluster_secrets" {
  count = var.deploy_crd == true ? 1 : 0
  manifest = {
    "apiVersion" = "external-secrets.io/v1beta1"
    "kind"       = "ClusterExternalSecret"
    "metadata" = {
      "name" = "cluster-secrets"
    }
    "spec" = {
      "externalSecretName" = "cluster-secrets-es"
      "namespaceSelector" = {
        "matchLabels" = var.namespace_selectors
      }
      "refreshTime" = var.refresh_time
      "externalSecretSpec" = {
        "secretStoreRef" = {
          "name" = "vault-backend"
          "kind" = "ClusterSecretStore"
        }
        "refreshInterval" = var.refresh_interval
        "target" = {
          "name" = "cluster-secrets"
        }
        "data" = var.secret_data
      }
    }
  }

  depends_on = [kubernetes_manifest.vault_secret_store]
}
