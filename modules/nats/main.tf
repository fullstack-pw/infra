resource "kubernetes_namespace" "nats" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

locals {
  namespace = var.create_namespace ? kubernetes_namespace.nats[0].metadata[0].name : var.namespace
}

resource "random_password" "nats_password" {
  count   = var.auth_enabled && var.generate_password ? 1 : 0
  length  = 16
  special = false
}

locals {
  nats_user     = var.auth_enabled ? var.nats_user : ""
  nats_password = var.auth_enabled && var.generate_password ? random_password.nats_password[0].result : var.nats_password
  auth_token    = var.auth_token_enabled && var.generate_auth_token ? random_password.nats_auth_token[0].result : var.auth_token
}

resource "random_password" "nats_auth_token" {
  count   = var.auth_token_enabled && var.generate_auth_token ? 1 : 0
  length  = 32
  special = false
}

resource "helm_release" "nats" {
  name       = var.release_name
  namespace  = local.namespace
  repository = "https://nats-io.github.io/k8s/helm/charts/"
  chart      = "nats"
  version    = var.chart_version
  timeout    = var.timeout

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      nats_user           = local.nats_user
      nats_password       = local.nats_password
      auth_enabled        = var.auth_enabled
      auth_token          = local.auth_token
      auth_token_enabled  = var.auth_token_enabled
      cluster_name        = var.cluster_name
      jetstream_enabled   = var.jetstream_enabled
      persistence_enabled = var.persistence_enabled
      storage_class       = var.persistence_storage_class
      storage_size        = var.persistence_size
      replicas            = var.replicas
      memory_request      = var.memory_request
      cpu_request         = var.cpu_request
      memory_limit        = var.memory_limit
      cpu_limit           = var.cpu_limit
      prometheus_enabled  = var.prometheus_enabled
      prometheus_port     = var.prometheus_port
      nats_port           = var.nats_port
      websocket_enabled   = var.websocket_enabled
      websocket_port      = var.websocket_port
      monitoring_enabled  = var.monitoring_enabled
      service_type        = var.service_type
      release_name        = var.release_name
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

# Create a Kubernetes Secret with auth credentials
resource "kubernetes_secret" "nats_credentials" {
  count = (var.auth_enabled || var.auth_token_enabled) && var.create_credentials_secret ? 1 : 0

  metadata {
    name      = "${var.release_name}-credentials"
    namespace = local.namespace
  }

  data = merge(
    var.auth_enabled ? {
      "nats_user"     = local.nats_user
      "nats_password" = local.nats_password
    } : {},
    var.auth_token_enabled ? {
      "auth_token" = local.auth_token
    } : {},
    {
      "nats_url" = "nats://nats.${local.namespace}.svc.cluster.local:${var.nats_port}"
    }
  )
}

# Create an Ingress for the NATS monitoring interface
resource "kubernetes_ingress_v1" "nats_ingress" {
  count = var.ingress_enabled && var.monitoring_enabled ? 1 : 0

  metadata {
    name      = "${var.release_name}-ingress"
    namespace = local.namespace
    annotations = merge({
      "kubernetes.io/ingress.class"               = var.ingress_class_name
      "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
      "cert-manager.io/cluster-issuer"            = var.cert_manager_cluster_issuer
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
              name = "nats"
              port {
                number = 8222 # NATS monitoring port
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
}
