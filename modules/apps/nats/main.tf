/**
 * NATS Module
 *
 * This module deploys NATS using our base modules for standardization.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

module "credentials" {
  source = "../../base/credentials"

  name              = "${var.release_name}-credentials"
  namespace         = module.namespace.name
  generate_password = var.generate_password
  password          = var.nats_password
  password_key      = "password"
  create_secret     = var.create_credentials_secret

  data = merge(
    {
      nats_url = "nats://${var.release_name}.${module.namespace.name}.svc.cluster.local:${var.nats_port}"
    },
    var.auth_enabled ? {
      nats_user     = var.nats_user
      nats_password = var.generate_password ? module.credentials.password : var.nats_password
    } : {},
    var.auth_token_enabled ? {
      auth_token = var.generate_auth_token ? random_password.nats_auth_token[0].result : var.auth_token
    } : {},
    var.websocket_enabled ? {
      websocket_url = "ws://${var.release_name}.${module.namespace.name}.svc.cluster.local:${var.websocket_port}"
    } : {}
  )
}

resource "random_password" "nats_auth_token" {
  count   = var.auth_token_enabled && var.generate_auth_token ? 1 : 0
  length  = 32
  special = false
}

locals {
  nats_user     = var.auth_enabled ? var.nats_user : ""
  nats_password = var.auth_enabled && var.generate_password ? module.credentials.password : var.nats_password
  auth_token    = var.auth_token_enabled && var.generate_auth_token ? random_password.nats_auth_token[0].result : var.auth_token
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
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
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "nats"
  repository       = "https://nats-io.github.io/k8s/helm/charts/"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

module "ingress" {
  source = "../../base/ingress"

  enabled            = var.ingress_enabled && var.monitoring_enabled
  name               = "${var.release_name}-ingress"
  namespace          = module.namespace.name
  host               = var.ingress_host
  service_name       = "${var.release_name}-headless"
  service_port       = 8222 # NATS monitoring port
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations        = var.ingress_annotations
}
