# resource "kubernetes_namespace" "cert_manager" {
#   metadata {
#     name = "cert-manager"
#   }
# }

# resource "helm_release" "cert_manager" {
#   name       = "cert-manager"
#   namespace  = kubernetes_namespace.cert_manager.metadata[0].name
#   chart      = "cert-manager"
#   repository = "https://charts.jetstack.io"
#   version    = "v1.16.2"

#   values = [
#     <<-EOF
#     installCRDs: true
#     EOF
#   ]

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
# }

# resource "kubernetes_manifest" "selfsigned_cluster_issuer" {
#   manifest = {
#     "apiVersion" = "cert-manager.io/v1"
#     "kind"       = "ClusterIssuer"
#     "metadata" = {
#       "name" = "selfsigned-cluster-issuer"
#     }
#     "spec" = {
#       "selfSigned" = {}
#     }
#   }
# }

# resource "kubernetes_manifest" "selfsigned_ca_certificate" {
#   manifest = {
#     "apiVersion" = "cert-manager.io/v1"
#     "kind"       = "Certificate"
#     "metadata" = {
#       "name"      = "my-selfsigned-ca"
#       "namespace" = "cert-manager"
#     }
#     "spec" = {
#       "isCA"       = true
#       "commonName" = "my-selfsigned-ca"
#       "secretName" = "root-secret"
#       "privateKey" = {
#         "algorithm" = "ECDSA"
#         "size"      = 256
#       }
#       "issuerRef" = {
#         "name"  = "selfsigned-issuer"
#         "kind"  = "ClusterIssuer"
#         "group" = "cert-manager.io"
#       }
#     }
#   }
# }

# resource "kubernetes_manifest" "selfsigned_issuer" {
#   manifest = {
#     "apiVersion" = "cert-manager.io/v1"
#     "kind"       = "ClusterIssuer"
#     "metadata" = {
#       "name" = "selfsigned-issuer"
#     }
#     "spec" = {
#       "selfSigned" = {}
#     }
#   }
# }

# resource "kubernetes_manifest" "ca_based_issuer" {
#   manifest = {
#     "apiVersion" = "cert-manager.io/v1"
#     "kind"       = "ClusterIssuer"
#     "metadata" = {
#       "name" = "my-ca-issuer"
#     }
#     "spec" = {
#       "ca" = {
#         "secretName" = "root-secret"
#       }
#     }
#   }
# }
