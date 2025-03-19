/**
 * Base credentials module
 * 
 * This module manages credentials and secrets in Kubernetes.
 */

resource "random_password" "password" {
  count   = var.generate_password ? 1 : 0
  length  = var.password_length
  special = var.password_special
}

locals {
  password = var.generate_password ? random_password.password[0].result : var.password
}

resource "kubernetes_secret" "this" {
  count = var.create_secret ? 1 : 0

  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = var.labels
  }

  data = merge(
    var.data,
    var.include_password && (var.generate_password || var.password != "") ? {
      "${var.password_key}" = local.password
    } : {}
  )

  type = var.secret_type
}
