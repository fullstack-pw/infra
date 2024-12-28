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

resource "kubernetes_persistent_volume_claim" "registry_storage" {
  metadata {
    name      = "registry-storage"
    namespace = kubernetes_namespace.registry.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path"
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}
