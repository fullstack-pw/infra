/**
 * ExternalDNS Module
 * 
 * This module deploys ExternalDNS to manage DNS records from Kubernetes resources.
 */

module "namespace" {
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
    name      = "external-dns"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "externaldns" {
  metadata {
    name = "external-dns"
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
}

resource "kubernetes_cluster_role_binding" "externaldns" {
  metadata {
    name = "external-dns-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.externaldns.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "external-dns"
    namespace = var.namespace
  }
}

resource "kubernetes_deployment" "externaldns" {
  metadata {
    name      = "external-dns"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "external-dns"
      }
    }

    template {
      metadata {
        labels = {
          app = "external-dns"
        }
      }

      spec {
        automount_service_account_token = true
        enable_service_links            = false
        service_account_name            = "external-dns"

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
