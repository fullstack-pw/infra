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
  version    = "v1.16.2"

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

data "vault_kv_secret_v2" "cloudflare" {
  mount = "kv"
  name  = "cloudflare"
}


resource "kubernetes_secret" "cloudflare-api-token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    api-token = data.vault_kv_secret_v2.cloudflare.data["api-token"]
  }
}

resource "kubernetes_manifest" "letsencrypt_issuer" {
  depends_on = [ helm_release.cert_manager ]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "server"  = "https://acme-v02.api.letsencrypt.org/directory"
        "email"   = "pedropilla@gmail.com"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "email" = "pedropilla@gmail.com"
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
