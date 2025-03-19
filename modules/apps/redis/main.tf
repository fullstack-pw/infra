/**
 * Redis Module
 * 
 * This module deploys Redis using our base modules for standardization.
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
  password          = var.redis_password
  password_key      = "redis_password"
  create_secret     = var.create_credentials_secret

  data = {
    redis_host        = "${var.release_name}-redis-master.${module.namespace.name}.svc.cluster.local"
    redis_port        = tostring(var.service_port)
    connection_string = "redis://:${var.generate_password ? module.credentials.password : var.redis_password}@${var.release_name}-redis-master.${module.namespace.name}.svc.cluster.local:${var.service_port}"
  }
}

module "values" {
  source = "../../base/values-template"

  template_files = [
    {
      path = "${path.module}/templates/values.yaml.tpl"
      vars = {
        redis_password      = module.credentials.password
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
        release_name        = var.release_name
      }
    }
  ]
}

module "helm" {
  source = "../../base/helm"

  release_name     = var.release_name
  namespace        = module.namespace.name
  chart            = "redis"
  repository       = "https://charts.bitnami.com/bitnami"
  chart_version    = var.chart_version
  timeout          = var.timeout
  create_namespace = false
  values_files     = module.values.rendered_values

  set_values = var.additional_set_values
}

module "ingress" {
  source = "../../base/ingress"

  enabled            = var.ingress_enabled
  name               = "${var.release_name}-redis-ingress"
  namespace          = module.namespace.name
  host               = var.ingress_host
  service_name       = "${var.release_name}-master"
  service_port       = var.service_port
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations        = var.ingress_annotations
}
