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
