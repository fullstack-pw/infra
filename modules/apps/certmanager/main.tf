/**
 * Cert Manager Module
 * 
 * This module deploys cert-manager with a Cloudflare DNS solver for ACME challenges.
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

// Deploy cert-manager via Helm
module "helm" {
  source = "../../base/helm"

  release_name     = "cert-manager"
  namespace        = module.namespace.name
  chart            = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart_version    = var.chart_version
  timeout          = 300
  create_namespace = false
  values_files = [
    <<-EOT
      installCRDs: true
    EOT
  ]
  set_values = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

// Fetch Cloudflare credentials from Vault
data "vault_kv_secret_v2" "cloudflare" {
  mount = "kv"
  name  = "cloudflare"
}

// Create Kubernetes secret for Cloudflare API token
module "cloudflare_secret" {
  source = "../../base/credentials"

  name              = "cloudflare-api-token"
  namespace         = module.namespace.name
  create_secret     = true
  generate_password = false

  data = {
    "api-token" = data.vault_kv_secret_v2.cloudflare.data["api-token"]
  }
}

// Create cluster issuer for Let's Encrypt production
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count      = var.install_crd == true ? 1 : 0
  depends_on = [module.helm]

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = var.cluster_issuer
    }
    "spec" = {
      "acme" = {
        "server" = var.acme_server
        "email"  = var.email
        "privateKeySecretRef" = {
          "name" = var.cluster_issuer
        }
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "email" = var.email
                "apiTokenSecretRef" = {
                  "name" = module.cloudflare_secret.name
                  "key"  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }
}
