/**
 * External Secrets Module
 * 
 * This module deploys the External Secrets operator with Vault integration
 * for managing Kubernetes secrets from external secret stores.
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

module "helm" {
  source = "../../base/helm"

  release_name     = "external-secrets"
  namespace        = module.namespace.name
  chart            = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  atomic           = true
  force_update     = true

  values_files = [
    <<-EOT
      installCRDs: true
    EOT
  ]

  set_values = []
}

// Create Secret for Vault token
module "vault_token_secret" {
  source = "../../base/credentials"

  name              = "vault-token"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = true

  data = {
    token = var.vault_token
  }
}

// Deploy ClusterSecretStore
resource "kubernetes_manifest" "vault_secret_store" {
  count = var.install_crd == true ? 1 : 0
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
              "name"      = module.vault_token_secret.name
              "namespace" = module.namespace.name
              "key"       = "token"
            }
          }
        }
      }
    }
  }

  depends_on = [module.helm]
}

// Deploy ClusterExternalSecret
resource "kubernetes_manifest" "cluster_secrets" {
  count = var.install_crd == true ? 1 : 0
  manifest = {
    "apiVersion" = "external-secrets.io/v1beta1"
    "kind"       = "ClusterExternalSecret"
    "metadata" = {
      "name" = "cluster-secrets"
    }
    "spec" = {
      "externalSecretName" = "cluster-secrets-es"
      "namespaceSelector" = var.namespace_selector_type == "name" ? {
        "matchLabels" = var.namespace_selectors
        } : {
        "matchLabels" = {
          "${var.namespace_selector_label.key}" = var.namespace_selector_label.value
        }
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
        "data" = concat(
          var.secret_data,
          var.include_pr_kubeconfig ? [
            {
              secretKey = "PR_KUBECONFIG"
              remoteRef = {
                key      = "cluster-secret-store/secrets"
                property = "PR_KUBECONFIG"
              }
            }
          ] : []
        )
      }
    }
  }

  depends_on = [kubernetes_manifest.vault_secret_store]
}
