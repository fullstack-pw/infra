
resource "kubernetes_namespace" "minio" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

resource "random_password" "minio_root_password" {
  count   = var.generate_root_credentials ? 1 : 0
  length  = 16
  special = false
}

locals {
  root_user     = var.generate_root_credentials ? "admin" : var.root_user
  root_password = var.generate_root_credentials ? random_password.minio_root_password[0].result : var.root_password
  namespace     = var.create_namespace ? kubernetes_namespace.minio[0].metadata[0].name : var.namespace
}

resource "helm_release" "minio" {
  name       = var.release_name
  namespace  = local.namespace
  chart      = "minio"
  repository = "https://charts.min.io/"
  version    = var.chart_version
  timeout    = var.timeout

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      root_user                       = local.root_user
      root_password                   = local.root_password
      mode                            = var.mode
      persistence_enabled             = var.persistence_enabled
      persistence_storage_class       = var.persistence_storage_class
      persistence_size                = var.persistence_size
      memory_request                  = var.memory_request
      ingress_enabled                 = var.ingress_enabled
      ingress_annotations             = var.ingress_annotations
      ingress_class_name              = var.ingress_class_name
      ingress_host                    = var.ingress_host
      ingress_tls_enabled             = var.ingress_tls_enabled
      ingress_tls_secret_name         = var.ingress_tls_secret_name
      console_ingress_enabled         = var.console_ingress_enabled
      console_ingress_annotations     = var.console_ingress_annotations
      console_ingress_class_name      = var.console_ingress_class_name
      console_ingress_host            = var.console_ingress_host
      console_ingress_tls_enabled     = var.console_ingress_tls_enabled
      console_ingress_tls_secret_name = var.console_ingress_tls_secret_name
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

# Optional: Create a secret with the minio credentials
resource "kubernetes_secret" "minio_credentials" {
  count = var.generate_root_credentials && var.create_credentials_secret ? 1 : 0
  metadata {
    name      = "${var.release_name}-credentials"
    namespace = local.namespace
  }

  data = {
    root_user     = local.root_user
    root_password = local.root_password
    s3_endpoint   = "https://${var.ingress_host}"
  }
}
