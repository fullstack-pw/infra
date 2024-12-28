resource "helm_release" "nginx" {
  name       = "nginx-ingress"
  namespace  = "default"
  chart      = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  version    = "1.2.0"

  values = [
    <<-EOF
controller:
  defaultTLS:
    secret: "default/fullstack-tls"
    EOF
  ] 

#   set {
#     name  = "installCRDs"
#     value = "true"
#   }
}

import {
  id = "default/nginx-ingress"
  to = helm_release.nginx
}

