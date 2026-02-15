## HELM
variable "base_additional_set_values" {
  description = "Additional values to set in the controller Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "release_name" {
  default = "immich"
}
variable "namespace" {
  default = "immich"
}
variable "chart" {
  default = "immich"
}
variable "repository" {
  default = "https://immich-app.github.io/immich-charts"
}
variable "chart_version" {
  default = "0.10.3"
}
variable "timeout" {
  default = "300"
}
variable "create_namespace" {
  default = false
}

variable "ingress_annotations" {
  type = map(string)
  default = {
    "external-dns.alpha.kubernetes.io/hostname"   = "immich.fullstack.pw"
    "cert-manager.io/cluster-issuer"              = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
    "nginx.org/client-max-body-size"              = "0"
  }
}

# IMMICH
variable "redis" {}
variable "redis_pass" {}
variable "db_hostname" {}
variable "db_user" {}
variable "db_name" {}
variable "db_pass" {}
variable "immich_domain" {}
variable "ingress_tls_secret_name" {
  default = "immich-tls"
}
