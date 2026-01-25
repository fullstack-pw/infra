locals {
  clusters = {
    for cluster in var.clusters : cluster.name => cluster
  }
}

module "namespace" {
  source = "../../../base/namespace"

  for_each = local.clusters

  create = true
  name   = each.value.name
  labels = {
    "kubernetes.io/metadata.name" = each.value.name
  }
  needs_secrets = true
}

resource "kubernetes_secret" "proxmox_credentials" {
  for_each = var.create_proxmox_secret ? local.clusters : {}

  metadata {
    name      = var.credentials_ref_name
    namespace = each.value.name
  }

  data = {
    url    = var.proxmox_url
    secret = var.proxmox_secret
    token  = var.proxmox_token
  }

  type = "Opaque"

  depends_on = [module.namespace]
}
