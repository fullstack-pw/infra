resource "kubernetes_namespace" "prometheus" {
  metadata {
    name = "prometheus"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.prometheus.metadata[0].name
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  #version    = "v11.1.1."
  values = [file("values.yaml")]

#   values = [
#     # <<-EOF
#     # installCRDs: true
#     # EOF
#   ]

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
}