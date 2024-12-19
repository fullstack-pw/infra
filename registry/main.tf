provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = "docker-registry"
  }
}

resource "kubernetes_manifest" "registry_deployment" {
  manifest = yamldecode(file("${path.module}/manifests/registry-deployment.yaml"))
}

resource "kubernetes_manifest" "registry_service" {
  manifest = yamldecode(file("${path.module}/manifests/registry-service.yaml"))
}
