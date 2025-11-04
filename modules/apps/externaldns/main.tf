/**
 * ExternalDNS Module
 * 
 * This module deploys ExternalDNS to manage DNS records from Kubernetes resources.
 */

module "namespace" {
  count  = var.create_namespace ? 1 : 0
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

resource "kubernetes_service_account" "externaldns" {
  automount_service_account_token = false
  metadata {
    name      = var.deployment_name
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "externaldns" {
  metadata {
    name = var.deployment_name
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["list", "watch"]
  }

  # Istio Gateway API support
  rule {
    api_groups = ["networking.istio.io"]
    resources  = ["gateways", "virtualservices"]
    verbs      = ["get", "watch", "list"]
  }

  # Gateway API support (optional, for future use)
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["gateways", "httproutes", "tlsroutes", "tcproutes", "udproutes"]
    verbs      = ["get", "watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "externaldns" {
  metadata {
    name = "${var.deployment_name}-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.externaldns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.deployment_name
    namespace = var.namespace
  }
}

resource "kubernetes_deployment" "externaldns" {
  metadata {
    name      = var.deployment_name
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.deployment_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.deployment_name
        }
      }

      spec {
        automount_service_account_token = true
        enable_service_links            = false
        service_account_name            = var.deployment_name

        container {
          name  = "external-dns"
          image = var.image

          env_from {
            prefix = null
            secret_ref {
              name     = "cluster-secrets"
              optional = true
            }
          }

          # PiHole-specific environment
          dynamic "env" {
            for_each = var.dns_provider == "pihole" ? [1] : []
            content {
              name = "EXTERNAL_DNS_PIHOLE_PASSWORD"
              value_from {
                secret_key_ref {
                  name = var.create_pihole_secret ? kubernetes_secret.pihole[0].metadata[0].name : var.pihole_secret_name
                  key  = "PIHOLE_PASSWORD"
                }
              }
            }
          }

          # Cloudflare-specific environment
          dynamic "env" {
            for_each = var.dns_provider == "cloudflare" ? [1] : []
            content {
              name = "CF_API_TOKEN"
              value_from {
                secret_key_ref {
                  name = var.create_cloudflare_secret ? kubernetes_secret.cloudflare[0].metadata[0].name : var.cloudflare_secret_name
                  key  = "api-token"
                }
              }
            }
          }

          args = var.container_args
        }

        security_context {
          fs_group        = "65534"
          run_as_non_root = false
        }
      }
    }
  }
}

resource "kubernetes_secret" "pihole" {
  count = var.create_pihole_secret ? 1 : 0

  metadata {
    name      = var.pihole_secret_name
    namespace = var.namespace
  }

  data = {
    PIHOLE_PASSWORD = var.pihole_password
  }
}

resource "kubernetes_secret" "cloudflare" {
  count = var.create_cloudflare_secret ? 1 : 0

  metadata {
    name      = var.cloudflare_secret_name
    namespace = var.namespace
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }
}
