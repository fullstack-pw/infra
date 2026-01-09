locals {
  clusters = { for cluster in var.managed_clusters : cluster.name => cluster }
}

module "namespace" {
  source = "../../base/namespace"
  create = var.create_namespace
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

resource "kubectl_manifest" "clusterrole" {
  yaml_body = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: cluster-autoscaler-clusterapi
    rules:
    - apiGroups: ["cluster.x-k8s.io"]
      resources: ["clusters", "machines", "machinedeployments", "machinesets"]
      verbs: ["get", "list", "watch"]
    - apiGroups: ["cluster.x-k8s.io"]
      resources: ["machinedeployments/scale", "machinesets/scale"]
      verbs: ["get", "update"]
    - apiGroups: ["infrastructure.cluster.x-k8s.io"]
      resources: ["*"]
      verbs: ["get", "list", "watch"]
  YAML
}

resource "kubectl_manifest" "clusterrolebinding" {
  yaml_body = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: cluster-autoscaler-clusterapi
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-autoscaler-clusterapi
    subjects:
    - kind: ServiceAccount
      name: cluster-autoscaler
      namespace: ${module.namespace.name}
  YAML

  depends_on = [kubectl_manifest.clusterrole]
}

module "values" {
  source = "../../base/values-template"
  template_files = [{
    path = "${path.module}/templates/values.yaml.tpl"
    vars = {
      cluster_name                  = var.managed_clusters[0].name
      cluster_namespace             = var.managed_clusters[0].namespace
      image_tag                     = var.image_tag
      scale_down_enabled            = var.scale_down_enabled
      scale_down_delay_after_add    = var.scale_down_delay_after_add
      scale_down_unneeded_time      = var.scale_down_unneeded_time
      skip_nodes_with_local_storage = var.skip_nodes_with_local_storage
      skip_nodes_with_system_pods   = var.skip_nodes_with_system_pods
      balance_similar_node_groups   = var.balance_similar_node_groups
      expander                      = var.expander
      replicas                      = var.replicas
    }
  }]
}

module "helm" {
  source = "../../base/helm"

  release_name     = "cluster-autoscaler"
  namespace        = module.namespace.name
  chart            = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart_version    = var.chart_version
  create_namespace = false
  values_files     = module.values.rendered_values
  set_values       = var.additional_set_values

  depends_on = [
    kubectl_manifest.clusterrolebinding
  ]
}
