
resource "kubernetes_namespace" "registry" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.registry[0].metadata[0].name : var.namespace
}

resource "kubernetes_deployment" "registry" {
  metadata {
    name      = var.deployment_name
    namespace = local.namespace
    labels = {
      app = var.app_label
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.app_label
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_label
        }
      }

      spec {
        container {
          name  = "registry"
          image = "${var.registry_image}:${var.registry_image_tag}"

          port {
            container_port = var.container_port
          }

          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }

          volume_mount {
            name       = "registry-storage"
            mount_path = "/var/lib/registry"
          }

          resources {
            limits = {
              cpu    = var.resources_limits_cpu
              memory = var.resources_limits_memory
            }
            requests = {
              cpu    = var.resources_requests_cpu
              memory = var.resources_requests_memory
            }
          }
        }

        volume {
          name = "registry-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.registry_storage.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "registry" {
  metadata {
    name      = var.service_name
    namespace = local.namespace
  }

  spec {
    selector = {
      app = var.app_label
    }

    port {
      port        = var.service_port
      target_port = var.container_port
    }

    type = var.service_type
  }
}

resource "kubernetes_persistent_volume_claim" "registry_storage" {
  metadata {
    name      = var.pvc_name
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_ingress_v1" "registry_ingress" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name      = var.ingress_name
    namespace = local.namespace
    annotations = merge({
      "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"    = "0"
      "external-dns.alpha.kubernetes.io/hostname"      = var.ingress_host
      "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
      "nginx.org/client-max-body-size"                 = "0"
    }, var.ingress_annotations)
  }

  spec {
    ingress_class_name = var.ingress_class_name

    tls {
      hosts       = [var.ingress_host]
      secret_name = var.tls_secret_name
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.registry.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }
}
