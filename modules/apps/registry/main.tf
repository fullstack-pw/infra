/**
 * Registry Module
 * 
 * This module deploys a Docker registry on Kubernetes with persistent storage and ingress.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "persistence" {
  source = "../../base/persistence"

  enabled       = true
  name          = var.pvc_name
  namespace     = module.namespace.name
  storage_class = var.storage_class
  size          = var.storage_size
  access_modes  = ["ReadWriteOnce"]
  use_selector  = false
}

resource "kubernetes_deployment" "registry" {
  metadata {
    name      = var.deployment_name
    namespace = module.namespace.name
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
            claim_name = module.persistence.name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "registry" {
  metadata {
    name      = var.service_name
    namespace = module.namespace.name
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

module "ingress" {
  source = "../../base/ingress"
  count  = var.create_ingress ? 1 : 0

  enabled            = true
  name               = var.ingress_name
  namespace          = module.namespace.name
  host               = var.ingress_host
  service_name       = kubernetes_service.registry.metadata[0].name
  service_port       = var.service_port
  path               = "/"
  tls_enabled        = true
  tls_secret_name    = var.tls_secret_name
  ingress_class_name = var.ingress_class_name

  annotations = merge({
    "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "0"
    "external-dns.alpha.kubernetes.io/hostname"      = var.ingress_host
    "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
    "nginx.org/client-max-body-size"                 = "0"
    "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
  }, var.ingress_annotations)
}
