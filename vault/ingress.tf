
resource "kubernetes_manifest" "vault_ingress" {
  manifest = yamldecode(file("${path.module}/manifests/vault-ingress.yaml"))
}