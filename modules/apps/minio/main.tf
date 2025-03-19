/**
 * MinIO Module
 * 
 * This module deploys MinIO S3-compatible object storage using our base modules.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

# Handle credentials generation
resource "random_password" "minio_root_password" {
  count   = var.generate_root_credentials ? 1 : 0
  length  = 16
  special = false
}

locals {
  root_user     = var.generate_root_credentials ? "admin" : var.root_user
  root_password = var.generate_root_credentials ? random_password.minio_root_password[0].result : var.root_password
}

module "credentials" {
  source = "../../base/credentials"

  name              = "${var.release_name}-credentials"
  namespace         = module.namespace.name
  generate_password = false # We handle password generation separately
  create_secret     = var.create_credentials_secret

  data = {
    root_user        = local.root_user
    root_password    = local.root_password
    s3_endpoint      = "https://${var.ingress_host}"
    console_endpoint = "https://${var.console_ingress_host}"
  }
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
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
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  repository       = "https://charts.min.io/"
  chart            = "minio"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

# Note: We don't need separate ingress modules here as MinIO chart creates its own ingresses
# based on the values we're providing in the template
