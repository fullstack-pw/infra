module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace

  labels = {
    "kubernetes.io/metadata.name"        = var.namespace
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/audit"   = "privileged"
    "pod-security.kubernetes.io/warn"    = "privileged"
  }
}

module "helm" {
  source = "../../base/helm"

  release_name     = "metallb"
  namespace        = module.namespace.name
  chart            = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart_version    = var.chart_version
  timeout          = 300
  create_namespace = false

  values_files = [
    <<-EOT
      resources:
        controller:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
        speaker:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 64Mi
    EOT
  ]

  set_values = []
}

resource "kubectl_manifest" "ip_address_pool" {
  count = var.create_ip_pool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: ${var.ip_pool_name}
      namespace: ${module.namespace.name}
    spec:
      addresses:
      %{for address in var.ip_pool_addresses~}
      - ${address}
      %{endfor~}
  YAML

  depends_on = [module.helm]
}

resource "kubectl_manifest" "l2_advertisement" {
  count = var.create_ip_pool ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: ${var.l2_advertisement_name}
      namespace: ${module.namespace.name}
    spec:
      ipAddressPools:
      - ${var.ip_pool_name}
  YAML

  depends_on = [kubectl_manifest.ip_address_pool]
}
