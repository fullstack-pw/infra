resource "helm_release" "vault" {
  name      = "vault"
  namespace = "vault"

  create_namespace = true

  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  values = [
    <<-EOF
    server:
      enabled: true
      standalone:
        enabled: true
      dataStorage:
        enabled: true
        size: 1Gi
        storageClass: hostpath
    ui:
      enabled: true
    EOF
  ]
}

# Expose Vault UI
resource "kubernetes_service" "vault_ui" {
  metadata {
    name      = "vault-ui-service"
    namespace = helm_release.vault.namespace
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "vault"
    }
    type = "NodePort"

    port {
      port        = 8200
      target_port = 8200
      node_port   = 30080 # Adjust the port as needed
    }
  }
}
