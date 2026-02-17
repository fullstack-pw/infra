/**
 * GitHub Runner Module
 *
 * This module deploys self-hosted GitHub Actions runners using the latest Actions Runner Controller (ARC).
 * It supports a custom runner image defined in the included Dockerfile, which adds
 * necessary tools like kubectl, Terraform, SOPS, and more.
 *
 * The custom image should be compatible with GitHub's runner architecture and include the
 * necessary tooling for your CI/CD pipelines.
 *
 * The runners automatically scale between min and max values and use secrets from 'cluster-secrets' for:
 * - Kubeconfig: Mounted at ~/.kube/config
 * - SOPS keys: Mounted at ~/.sops/keys/sops-key.txt
 * - Environment variables: All variables from cluster-secrets
 */

module "namespace" {
  source = "../../base/namespace"

  create = true
  name   = var.namespace
  labels = {
    "kubernetes.io/metadata.name" = var.namespace
  }
  needs_secrets = true
}

# Deploy the controller (cluster-wide component)
module "controller_helm" {
  source = "../../base/helm"

  release_name     = "gha-runner-scale-set-controller"
  namespace        = module.namespace.name
  chart            = "gha-runner-scale-set-controller"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart_version    = var.controller_chart_version
  timeout          = 300
  create_namespace = false

  values_files = [templatefile("${path.module}/templates/controller-values.yaml.tpl", {
    github_token = var.github_token
  })]

  set_values = concat([], var.controller_additional_set_values)
}

# Create service account for runners
resource "kubernetes_service_account" "github_runner" {
  metadata {
    name      = var.service_account_name
    namespace = module.namespace.name
  }
}

# Deploy the runner scale set
module "runner_helm" {
  source = "../../base/helm"

  release_name     = var.runner_name
  namespace        = module.namespace.name
  chart            = "gha-runner-scale-set"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart_version    = var.runner_chart_version
  timeout          = 300
  create_namespace = false

  values_files = [templatefile("${path.module}/templates/runner-values.yaml.tpl", {
    namespace         = module.namespace.name
    github_owner      = var.github_owner
    runner_name       = var.runner_name
    min_runners       = var.min_runners
    max_runners       = var.max_runners
    runner_image      = var.runner_image
    runner_labels     = var.runner_labels
    working_directory = var.working_directory
  })]

  depends_on = [module.controller_helm]
}

resource "kubernetes_deployment" "buildkitd" {
  count = var.enable_buildkit_runners ? 1 : 0

  metadata {
    name      = "buildkitd"
    namespace = module.namespace.name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "buildkitd"
      }
    }

    template {
      metadata {
        labels = {
          app = "buildkitd"
        }
      }

      spec {
        container {
          name  = "buildkitd"
          image = var.buildkit_image

          args = [
            "--addr", "tcp://0.0.0.0:1234",
          ]

          security_context {
            privileged = true
            seccomp_profile {
              type = "Unconfined"
            }
          }

          port {
            container_port = 1234
            name           = "buildkit"
          }

          volume_mount {
            name       = "buildkit-storage"
            mount_path = "/var/lib/buildkit"
          }

          readiness_probe {
            exec {
              command = ["buildctl", "--addr", "tcp://localhost:1234", "debug", "workers"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          resources {
            limits = {
              cpu    = "2"
              memory = "4Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        volume {
          name = "buildkit-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "buildkitd" {
  count = var.enable_buildkit_runners ? 1 : 0

  metadata {
    name      = "buildkitd"
    namespace = module.namespace.name
  }

  spec {
    selector = {
      app = "buildkitd"
    }

    port {
      port        = 1234
      target_port = 1234
      name        = "buildkit"
    }
  }
}

module "runner_helm_buildkit" {
  count  = var.enable_buildkit_runners ? 1 : 0
  source = "../../base/helm"

  release_name     = var.buildkit_runner_name
  namespace        = module.namespace.name
  chart            = "gha-runner-scale-set"
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart_version    = var.runner_chart_version
  timeout          = 300
  create_namespace = false

  values_files = [templatefile("${path.module}/templates/runner-values-buildkit.yaml.tpl", {
    namespace         = module.namespace.name
    github_owner      = var.github_owner
    runner_name       = var.buildkit_runner_name
    min_runners       = var.min_runners
    max_runners       = var.max_runners
    runner_image      = var.runner_image
    runner_labels     = var.runner_labels
    working_directory = var.working_directory
  })]

  depends_on = [module.controller_helm]
}
