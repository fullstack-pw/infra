terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

# KubeVirt CR
resource "kubectl_manifest" "kubevirt_cr" {
  count = var.create_kubevirt_cr ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/kubevirt-cr.yaml.tpl", {
    namespace     = var.namespace
    feature_gates = var.kubevirt_feature_gates
  })

  wait              = true
  server_side_apply = true
}

# CDI CR
resource "kubectl_manifest" "cdi_cr" {
  count = var.create_cdi_cr ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/cdi-cr.yaml.tpl", {
    namespace     = var.namespace
    feature_gates = var.cdi_feature_gates
  })

  wait              = true
  server_side_apply = true

  depends_on = [kubectl_manifest.kubevirt_cr]
}

# CDI Upload Proxy Ingress (if enabled)
module "cdi_ingress" {
  source = "../../base/ingress"
  count  = var.create_cdi_cr && var.enable_cdi_uploadproxy_ingress ? 1 : 0

  enabled            = true
  name               = "cdi-uploadproxy-ingress"
  namespace          = "cdi"
  host               = var.cdi_uploadproxy_host
  service_name       = "cdi-uploadproxy"
  service_port       = 443
  tls_enabled        = true
  tls_secret_name    = "cdi-uploadproxy-tls"
  ingress_class_name = var.ingress_class_name
  annotations = merge({
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "0"
    "nginx.org/client-max-body-size"                    = "0"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "600"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "600"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }, var.cdi_uploadproxy_ingress_annotations)

  depends_on = [kubectl_manifest.cdi_cr]
}

module "export_ingress" {
  source = "../../base/ingress"
  count  = var.create_cdi_cr && var.enable_cdi_uploadproxy_ingress ? 1 : 0

  enabled            = true
  name               = "virt-exportproxy-ingress"
  namespace          = "kubevirt"
  host               = var.virt_exportproxy_host
  service_name       = "virt-exportproxy"
  service_port       = 443
  tls_enabled        = true
  tls_secret_name    = "virt-exportproxy-tls"
  ingress_class_name = var.ingress_class_name
  annotations = merge({
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "0"
    "nginx.org/client-max-body-size"                    = "0"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "600"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "600"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }, var.cdi_uploadproxy_ingress_annotations)

  depends_on = [kubectl_manifest.cdi_cr]
}
