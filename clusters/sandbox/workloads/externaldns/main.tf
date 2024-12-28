resource "kubernetes_service_account" "externaldns" {
  automount_service_account_token = false
  metadata {
    name      = "external-dns"
    namespace = "default"
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
    namespace = "default"
  }
}
resource "kubernetes_deployment" "externaldns" {
  metadata {
    name      = "external-dns"
    namespace = "default"
  }

  spec {
    replicas = 1

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
        automount_service_account_token = false
        enable_service_links = false
        service_account_name = "external-dns"

        container {
          name  = "external-dns"
          image = "registry.k8s.io/external-dns/external-dns:v0.14.1"
            env_from {
                prefix = null
                secret_ref {
                    name     = "pihole-password"
                    optional = false
                }
            }
          args = [
            "--pihole-tls-skip-verify",
            "--source=ingress",
            "--registry=noop",
            "--policy=upsert-only",
            "--provider=pihole",
            "--pihole-server=http://192.168.1.3",
          ]
        }
                  security_context {
                      fs_group               = "65534"
                        fs_group_change_policy = null
                        run_as_group           = null
                      run_as_non_root        = false
                        run_as_user            = null
                      supplemental_groups    = []
                    }
      }
    }
  }
}


import {
    to = kubernetes_service_account.externaldns
    id = "default/external-dns"
    }
import {
    to = kubernetes_cluster_role.externaldns
    id = "external-dns"
    }
import {
    to = kubernetes_cluster_role_binding.externaldns
    id = "external-dns-viewer"
    }
import {
    to = kubernetes_deployment.externaldns
    id = "default/external-dns"
    }