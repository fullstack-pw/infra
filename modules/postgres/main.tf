resource "kubernetes_namespace" "postgres" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.postgres[0].metadata[0].name : var.namespace
}

resource "random_password" "postgres_password" {
  count   = var.generate_credentials ? 1 : 0
  length  = 16
  special = false
}

locals {
  postgres_username = var.generate_credentials ? "admin" : var.postgres_username
  postgres_password = var.generate_credentials ? random_password.postgres_password[0].result : var.postgres_password
  postgres_database = var.postgres_database != "" ? var.postgres_database : "postgres"
}

resource "helm_release" "postgres" {
  name       = var.release_name
  namespace  = local.namespace
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = var.chart_version
  timeout    = var.timeout

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      postgres_username    = local.postgres_username
      postgres_password    = local.postgres_password
      postgres_database    = local.postgres_database
      persistence_enabled  = var.persistence_enabled
      storage_class        = var.persistence_storage_class
      persistence_size     = var.persistence_size
      memory_request       = var.memory_request
      cpu_request          = var.cpu_request
      memory_limit         = var.memory_limit
      cpu_limit            = var.cpu_limit
      enable_metrics       = var.enable_metrics
      pg_version           = var.postgres_version
      service_type         = var.service_type
      service_port         = var.service_port
      replication_enabled  = var.replication_enabled
      replication_replicas = var.replication_replicas
      ha_enabled           = var.high_availability_enabled
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

# Optional: Create a secret with the postgres credentials
resource "kubernetes_secret" "postgres_credentials" {
  count = var.generate_credentials && var.create_credentials_secret ? 1 : 0
  metadata {
    name      = "${var.release_name}-credentials"
    namespace = local.namespace
  }

  data = {
    username          = local.postgres_username
    password          = local.postgres_password
    database          = local.postgres_database
    postgres_host     = "${var.release_name}-postgresql.${local.namespace}.svc.cluster.local"
    postgres_port     = var.service_port
    connection_string = "postgresql://${local.postgres_username}:${local.postgres_password}@${var.release_name}-postgresql.${local.namespace}.svc.cluster.local:${var.service_port}/${local.postgres_database}"
  }
}

# Create a dedicated Ingress for PostgreSQL if enabled
resource "kubernetes_ingress_v1" "postgres_ingress" {
  count = var.ingress_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-postgresql-ingress"
    namespace = local.namespace
    annotations = merge({
      "nginx.ingress.kubernetes.io/ssl-redirect"  = tostring(var.ingress_tls_enabled)
      "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
      "cert-manager.io/cluster-issuer"            = var.cert_manager_cluster_issuer
      # Add PostgreSQL-specific annotations
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "50m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
      # This is critical for PostgreSQL through ingress
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/ssl-passthrough"  = "true"
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
              name = "${var.release_name}-postgresql"
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

  depends_on = [helm_release.postgres]
}
