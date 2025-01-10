resource "helm_release" "external-secrets" {
  name      = "external-secrets"
  namespace = "external-secrets"
  force_update = true
  timeout = 120
  version = "0.12.1"
  atomic = true

  create_namespace = true

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

values = [ <<-EOF
installCRDs: false
EOF 
]
}

resource "kubernetes_manifest" "vault-secret-store" {
  manifest = yamldecode(file("${path.module}/manifests/vault-secret-store.yaml"))
  depends_on = [ helm_release.external-secrets ]
}

resource "kubernetes_manifest" "cluster-secrets" {
  manifest = yamldecode(file("${path.module}/manifests/cluster-secrets.yaml"))
  depends_on = [ helm_release.external-secrets ]
}
