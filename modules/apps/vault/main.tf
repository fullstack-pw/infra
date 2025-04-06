/**
 * Vault Module
 * 
 * This module deploys HashiCorp Vault on Kubernetes using our base modules for standardization.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
}

locals {
  namespace = module.namespace.name
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        ui_enabled                 = var.ui_enabled
        data_storage_enabled       = var.data_storage_enabled
        data_storage_storage_class = var.data_storage_storage_class
        ingress_enabled            = var.ingress_enabled
        ingress_class_name         = var.ingress_class_name
        ingress_annotations        = var.ingress_annotations
        ingress_host               = var.ingress_host
        tls_secret_name            = var.tls_secret_name
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = local.namespace
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  chart_version    = var.chart_version
  create_namespace = false
  force_update     = var.force_update
  timeout          = var.timeout
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

# Only create these resources if initialize_vault is true
resource "vault_mount" "kv" {
  count       = var.initialize_vault ? 1 : 0
  path        = var.kv_path
  type        = "kv"
  description = "Key-Value store for secrets"
  options = {
    version = "2"
  }
  depends_on = [module.helm]
}

resource "vault_auth_backend" "kubernetes" {
  count       = var.initialize_vault ? 1 : 0
  type        = "kubernetes"
  description = "Kubernetes Auth Method"
  depends_on  = [module.helm]
}

resource "vault_kubernetes_auth_backend_config" "config" {
  count              = var.initialize_vault ? 1 : 0
  backend            = vault_auth_backend.kubernetes[0].path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
  token_reviewer_jwt = var.token_reviewer_jwt
  depends_on         = [module.helm]
}

# Dynamic block to create initial secrets
resource "vault_kv_secret_v2" "initial_secrets" {
  for_each = var.initialize_vault ? var.initial_secrets : {}

  mount     = vault_mount.kv[0].path
  name      = length(regexall("^kv/", each.key)) > 0 ? substr(each.key, 3, length(each.key) - 3) : each.key
  data_json = jsonencode(each.value)

  depends_on = [vault_mount.kv]
}

# Dynamic block to create initial policies
resource "vault_policy" "policies" {
  for_each = var.initialize_vault ? var.policies : {}

  name   = each.key
  policy = each.value

  depends_on = [vault_mount.kv]
}
