module "namespace" {
  source        = "../../base/namespace"
  create        = true
  name          = var.namespace
  needs_secrets = true
}

module "argocd_values" {
  source = "../../base/values-template"

  template_files = [{
    path = "${path.module}/templates/argocd-values.yaml.tpl"
    vars = {
      domain                    = var.argocd_domain
      ingress_enabled           = var.ingress_enabled
      ingress_class_name        = var.ingress_class_name
      cert_issuer               = var.cert_issuer
      admin_password_bcrypt     = var.admin_password_bcrypt
      application_namespaces    = var.application_namespaces
      enable_notifications      = var.enable_notifications
      enable_dex                = var.enable_dex
      server_cpu_request        = var.server_resources.requests.cpu
      server_memory_request     = var.server_resources.requests.memory
      server_cpu_limit          = var.server_resources.limits.cpu
      server_memory_limit       = var.server_resources.limits.memory
      repo_cpu_request          = var.repo_server_resources.requests.cpu
      repo_memory_request       = var.repo_server_resources.requests.memory
      repo_cpu_limit            = var.repo_server_resources.limits.cpu
      repo_memory_limit         = var.repo_server_resources.limits.memory
      controller_cpu_request    = var.controller_resources.requests.cpu
      controller_memory_request = var.controller_resources.requests.memory
      controller_cpu_limit      = var.controller_resources.limits.cpu
      controller_memory_limit   = var.controller_resources.limits.memory
    }
  }]
}

module "helm" {
  source = "../../base/helm"

  release_name     = "argocd"
  namespace        = module.namespace.name
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart_version    = var.argocd_version
  timeout          = 600
  create_namespace = false
  values_files     = module.argocd_values.rendered_values

  depends_on = [module.namespace]
}

# Istio VirtualService for routing traffic to Argo CD
resource "kubernetes_manifest" "argocd_virtualservice" {
  count = var.use_istio && var.ingress_enabled ? 1 : 0

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "argocd-server"
      namespace = module.namespace.name
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        # "external-dns.alpha.kubernetes.io/hostname" = var.argocd_domain
        # "external-dns.alpha.kubernetes.io/target"   = "192.168.1.12"
      }
    }
    spec = {
      hosts = [
        var.argocd_domain
      ]
      gateways = [
        "istio-system/default-gateway"
      ]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "argocd-server.${module.namespace.name}.svc.cluster.local"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [module.helm]
}
