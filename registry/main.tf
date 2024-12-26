provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kubernetes-admin@kubernetes"
}

resource "kubernetes_namespace" "registry" {
  metadata {
    name = "registry"
  }
}

resource "kubernetes_manifest" "registry_deployment" {
  manifest = yamldecode(file("${path.module}/manifests/registry-deployment.yaml"))
}

resource "kubernetes_manifest" "registry_service" {
  manifest = yamldecode(file("${path.module}/manifests/registry-service.yaml"))
}

resource "kubernetes_manifest" "registry_ingress" {
  manifest = yamldecode(file("${path.module}/manifests/registry-ingress.yaml"))
}
