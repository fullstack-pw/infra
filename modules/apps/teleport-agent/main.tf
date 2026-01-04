/**
 * Teleport Agent Module
 * 
 * This module deploys Teleport agents to Kubernetes clusters
 * to enable secure access through the main Teleport cluster.
 */

module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

# Retrieve join token from main Teleport cluster
data "external" "join_token" {
  program = ["bash", "-c", "echo '{\"token\":\"'$TELEPORT_JOIN_TOKEN'\"}'"]
}

locals {
  databases_with_ca = { for name, db in var.databases : name => db if db.ca_cert != "" }
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        cluster_name            = var.cluster_name
        teleport_version        = var.teleport_version
        proxy_server            = var.proxy_server
        join_token              = var.join_token
        ca_pin                  = var.ca_pin
        kubernetes_cluster_name = var.kubernetes_cluster_name
        enable_metrics          = var.enable_metrics
        log_level               = var.log_level
        node_selector           = var.node_selector
        tolerations             = var.tolerations
        resources               = var.resources
        roles                   = var.roles
        apps                    = var.apps
        databases               = var.databases
        ssl_ca_cert_key         = var.ssl_ca_cert_key
      }
    }
  ]
}

resource "kubernetes_secret" "db_ca" {
  for_each = local.databases_with_ca

  metadata {
    name      = "${each.key}-ca"
    namespace = module.namespace.name
  }

  data = {
    "ca.pem" = each.value.ca_cert
  }
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "teleport-kube-agent"
  repository       = "https://charts.releases.teleport.dev"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values

  depends_on = [kubernetes_secret.db_ca]
}

# Create RBAC for Teleport agent
resource "kubernetes_cluster_role" "teleport_agent" {
  metadata {
    name = "${var.release_name}-agent"
  }

  rule {
    api_groups = [""]
    resources  = ["users", "groups", "serviceaccounts"]
    verbs      = ["impersonate"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources  = ["selfsubjectaccessreviews", "selfsubjectrulesreviews"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "teleport_agent" {
  metadata {
    name = "${var.release_name}-agent"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.teleport_agent.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "${var.release_name}-agent"
    namespace = module.namespace.name
  }
}

# Optional: Create role for limited access users
resource "kubernetes_cluster_role" "teleport_limited" {
  count = var.create_limited_role ? 1 : 0

  metadata {
    name = "${var.release_name}-limited"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints"]
    verbs      = ["get", "list"]
  }
}
