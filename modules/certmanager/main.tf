resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = var.chart_version

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

// Fetch Cloudflare credentials from Vault
data "vault_kv_secret_v2" "cloudflare" {
  mount = "kv"
  name  = "cloudflare"
}

// Create Kubernetes secret for Cloudflare API token
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    api-token = data.vault_kv_secret_v2.cloudflare.data["api-token"]
  }
}

// Create cluster issuer for Let's Encrypt production
resource "kubernetes_manifest" "letsencrypt_issuer" {
  count      = var.install_crd == true ? 1 : 0
  depends_on = [helm_release.cert_manager]

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
                  "name" = "cloudflare-api-token"
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
