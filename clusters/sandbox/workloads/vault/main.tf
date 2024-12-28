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
      ingress:
        enabled: true
        ingressClassName: "nginx"
        annotations:
          external-dns.alpha.kubernetes.io/hostname: vault.fullstack.pw
          cert-manager.io/cluster-issuer: letsencrypt-prod
        hosts:
          - host: vault.fullstack.pw
        tls:
        - secretName: vault-tls
          hosts:
            - vault.fullstack.pw
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
