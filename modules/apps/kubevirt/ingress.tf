module "ingress" {
  source = "../../base/ingress"

  name               = "cdi-uploadproxy-ingress"
  namespace          = "cdi"
  host               = "cdi.uploadproxy.fullstack.pw"
  service_name       = "cdi-uploadproxy"
  service_port       = "443"
  tls_enabled        = true
  tls_secret_name    = "cdi-uploadproxy-ingress-tls"
  ingress_class_name = "traefik"
  annotations = {
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "0"
    "nginx.org/client-max-body-size"                    = "0"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }
}
