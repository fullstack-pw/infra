/**
 * GitHub Runner Module
 * 
 * This module deploys GitHub Actions runners on Kubernetes using the Actions Runner Controller (ARC).
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
}

module "credentials" {
  source = "../../base/credentials"

  name              = "github-pat"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = false

  data = {
    github_token = var.github_token
  }
}

module "kubeconfig_secret" {
  source = "../../base/credentials"

  name              = "kubeconfig"
  namespace         = module.namespace.name
  generate_password = false
  create_secret     = false

  data = {
    kubeconfig = var.kubeconfig
  }
}

# Deploy the GitHub Actions runner controller
module "helm" {
  source = "../../base/helm"

  release_name     = "actions-runner-controller"
  namespace        = module.namespace.name
  chart            = "actions-runner-controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart_version    = var.arc_chart_version
  timeout          = 120
  create_namespace = false

  values_files = []

  set_values = [{
    name  = "authSecret.create"
    value = "true"
    },
    {
      name  = "authSecret.github_token"
      value = var.github_token
    },
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "certManagerEnabled"
      value = tostring(var.cert_manager_enabled)
    },
    {
      name  = "image.actionsRunnerRepositoryAndTag"
      value = var.runner_image
  }]
}

# Create service account for GitHub runners
resource "kubernetes_service_account" "github_runner" {
  metadata {
    name      = "github-runner"
    namespace = module.namespace.name
  }
}

# Create runner deployment manifest
resource "kubernetes_manifest" "runner_deployment" {
  count = var.install_crd == true ? 1 : 0
  manifest = {
    apiVersion = "actions.summerwind.dev/v1alpha1"
    kind       = "RunnerDeployment"
    metadata = {
      name      = var.runner_name
      namespace = module.namespace.name
    }
    spec = {
      replicas = var.runner_replicas
      template = {
        spec = {
          volumes = [
            {
              name = "kubeconfig-volume"
              secret = {
                secretName = "cluster-secrets"
                items = [
                  {
                    key  = "KUBECONFIG"
                    path = "kubeconfig"
                  }
                ]
              }
            }
          ]
          organization       = var.github_owner
          serviceAccountName = kubernetes_service_account.github_runner.metadata[0].name
          envFrom = [
            {
              secretRef = {
                name = "cluster-secrets"
              }
            }
          ]
          containers = [
            {
              name = "runner"
              volumeMounts = [
                {
                  name      = "kubeconfig-volume"
                  mountPath = "/home/runner/.kube/config"
                  subPath   = "kubeconfig"
                }
              ]
              labels     = var.runner_labels != "" ? [var.runner_labels] : null
              image      = var.runner_image_override != "" ? var.runner_image_override : null
              workingDir = var.working_directory != "" ? var.working_directory : null
            }
          ]
        }
      }
    }
  }

  depends_on = [module.helm]
}

# Create horizontal autoscaler if enabled
resource "kubernetes_manifest" "runner_autoscaler" {
  count = var.enable_autoscaling ? 1 : 0

  manifest = {
    apiVersion = "actions.summerwind.dev/v1alpha1"
    kind       = "HorizontalRunnerAutoscaler"
    metadata = {
      name      = "${var.runner_name}-autoscaler"
      namespace = module.namespace.name
    }
    spec = {
      scaleTargetRef = {
        kind = "RunnerDeployment"
        name = var.runner_name
      }
      minReplicas = var.min_runners
      maxReplicas = var.max_runners
      metrics = [
        {
          type               = "PercentageRunnersBusy"
          scaleUpThreshold   = var.scale_up_threshold
          scaleDownThreshold = var.scale_down_threshold
          scaleUpFactor      = var.scale_up_factor
          scaleDownFactor    = var.scale_down_factor
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.runner_deployment]
}
