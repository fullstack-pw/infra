resource "kubernetes_namespace" "redis" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.redis[0].metadata[0].name : var.namespace
}

resource "random_password" "redis_password" {
  count   = var.generate_password ? 1 : 0
  length  = 16
  special = false
}

locals {
  redis_password = var.generate_password ? random_password.redis_password[0].result : var.redis_password
}

resource "helm_release" "redis" {
  name       = var.release_name
  namespace  = local.namespace
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = var.chart_version
  timeout    = var.timeout

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      redis_password      = local.redis_password
      architecture        = var.sentinel_enabled ? "replication" : "standalone"
      sentinel_enabled    = var.sentinel_enabled
      sentinel_quorum     = var.sentinel_quorum
      replicas            = var.replicas
      persistence_enabled = var.persistence_enabled
      storage_class       = var.persistence_storage_class
      persistence_size    = var.persistence_size
      auth_enabled        = var.auth_enabled
      memory_request      = var.memory_request
      cpu_request         = var.cpu_request
      memory_limit        = var.memory_limit
      cpu_limit           = var.cpu_limit
      enable_metrics      = var.enable_metrics
      service_type        = var.service_type
      service_port        = var.service_port
    })
  ]

  dynamic "set" {
    for_each = var.additional_set_values
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}

# Optional: Create a secret with the redis credentials
resource "kubernetes_secret" "redis_credentials" {
  count = var.generate_password && var.create_credentials_secret ? 1 : 0
  metadata {
    name      = "${var.release_name}-credentials"
    namespace = local.namespace
  }

  data = {
    redis_password      = local.redis_password
    redis_host          = "${var.release_name}-redis-master.${local.namespace}.svc.cluster.local"
    redis_port          = var.service_port
    connection_string   = "redis://:${local.redis_password}@${var.release_name}-redis-master.${local.namespace}.svc.cluster.local:${var.service_port}"
    sentinel_host       = var.sentinel_enabled ? "${var.release_name}-redis-headless.${local.namespace}.svc.cluster.local" : null
    sentinel_port       = var.sentinel_enabled ? "26379" : null
    sentinel_connection = var.sentinel_enabled ? "redis+sentinel://:${local.redis_password}@${var.release_name}-redis-headless.${local.namespace}.svc.cluster.local:26379/mymaster" : null
  }
}

# Create a dedicated Ingress for Redis if enabled
resource "kubernetes_ingress_v1" "redis_ingress" {
  count = var.ingress_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-redis-ingress"
    namespace = local.namespace
    annotations = merge({
      "nginx.ingress.kubernetes.io/ssl-redirect"  = tostring(var.ingress_tls_enabled)
      "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
      "cert-manager.io/cluster-issuer"            = var.cert_manager_cluster_issuer
      # Add Redis-specific annotations
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "10m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
      # TCP services for Redis
      "nginx.ingress.kubernetes.io/service-upstream" = "true"
    }, var.ingress_annotations)
  }

  spec {
    ingress_class_name = var.ingress_class_name

    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${var.release_name}-master"
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }

    dynamic "tls" {
      for_each = var.ingress_tls_enabled ? [1] : []
      content {
        hosts       = [var.ingress_host]
        secret_name = var.ingress_tls_secret_name
      }
    }
  }

  depends_on = [helm_release.redis]
}
