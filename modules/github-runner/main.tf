data "vault_kv_secret_v2" "github_token" {
  mount = "kv"
  name  = "github-runner"
}

resource "kubernetes_namespace" "arc_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "kubeconfig" {
  metadata {
    name      = "kubeconfig"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }

  data = {
    KUBECONFIG = data.vault_kv_secret_v2.github_token.data["KUBECONFIG"]
  }
}

resource "kubernetes_secret" "github_pat" {
  metadata {
    name      = "github-pat"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }

  data = {
    GITHUB_PAT = data.vault_kv_secret_v2.github_token.data["GITHUB_PAT"]
  }
}

# Create a Kubernetes Service Account
resource "kubernetes_service_account" "github_runner" {
  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.arc_namespace.metadata[0].name
  }
}

# Deploy the GitHub Actions runner controller
resource "helm_release" "arc" {
  name       = "actions-runner-controller"
  namespace  = kubernetes_namespace.arc_namespace.metadata[0].name
  chart      = "actions-runner-controller"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  version    = var.arc_chart_version

  set {
    name  = "authSecret.create"
    value = true
  }

  set {
    name  = "authSecret.github_token"
    value = data.vault_kv_secret_v2.github_token.data["GITHUB_PAT"]
  }

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "certManagerEnabled"
    value = var.cert_manager_enabled
  }

  set {
    name  = "image.actionsRunnerRepositoryAndTag"
    value = var.runner_image
  }
}

resource "kubernetes_manifest" "runner_deployment" {
  manifest = {
    "apiVersion" = "actions.summerwind.dev/v1alpha1"
    "kind"       = "RunnerDeployment"
    "metadata" = {
      "name"      = "github-runner"
      "namespace" = kubernetes_namespace.arc_namespace.metadata[0].name
    }
    "spec" = {
      "replicas" = var.runner_replicas
      "template" = {
        "spec" = {
          "organization"       = var.github_owner
          "serviceAccountName" = kubernetes_service_account.github_runner.metadata[0].name
          "containers" = [
            {
              "name" = "runner"
              "env" = [
                {
                  "name"  = "KUBECONFIG"
                  "value" = "/etc/kubeconfig"
                }
              ]
              "volumeMounts" = [
                {
                  "name"      = "kubeconfig-volume"
                  "mountPath" = "/etc/kubeconfig"
                  "subPath"   = "KUBECONFIG"
                }
              ]
            }
          ]
          "volumes" = [
            {
              "name" = "kubeconfig-volume"
              "secret" = {
                "secretName" = "kubeconfig"
              }
            }
          ]
        }
      }
    }
  }
  depends_on = [helm_release.arc]
}

resource "kubernetes_manifest" "runner_autoscaler" {
  count = var.enable_autoscaling ? 1 : 0

  manifest = {
    "apiVersion" = "actions.summerwind.dev/v1alpha1"
    "kind"       = "HorizontalRunnerAutoscaler"
    "metadata" = {
      "name"      = "github-runner-autoscaler"
      "namespace" = kubernetes_namespace.arc_namespace.metadata[0].name
    }
    "spec" = {
      "scaleTargetRef" = {
        "kind" = "RunnerDeployment"
        "name" = "github-runner"
      }
      "minReplicas" = var.min_runners
      "maxReplicas" = var.max_runners
      "metrics" = [
        {
          "type"               = "PercentageRunnersBusy"
          "scaleUpThreshold"   = var.scale_up_threshold
          "scaleDownThreshold" = var.scale_down_threshold
          "scaleUpFactor"      = var.scale_up_factor
          "scaleDownFactor"    = var.scale_down_factor
        }
      ]
    }
  }
  depends_on = [kubernetes_manifest.runner_deployment]
}
