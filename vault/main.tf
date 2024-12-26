resource "helm_release" "vault" {
  name      = "vault"
  namespace = "vault"
  force_update = true

  create_namespace = true

  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  values = [
    <<-EOF
    server:
      dataStorage:
        storageClass: hostpath
    ui:
      enabled: true
    EOF
  ]
}

resource "vault_mount" "kv" {
  path = "kv"
  type = "kv-v2"
  description = "Key-Value store for secrets"
  depends_on = [ helm_release.vault ]
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  description = "Kubernetes Auth Method"
  depends_on = [ helm_release.vault ]
}

resource "vault_kubernetes_auth_backend_config" "auth" {
  backend      = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
  kubernetes_ca_cert  = var.kubernetes_ca_cert
  token_reviewer_jwt  = var.token_reviewer_jwt
  depends_on = [ helm_release.vault ]
}
