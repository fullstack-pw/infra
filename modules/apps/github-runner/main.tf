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
    namespace            = module.namespace.name
    github_owner         = var.github_owner
    runner_name          = var.runner_name
    service_account_name = kubernetes_service_account.github_runner.metadata[0].name
    min_runners          = var.min_runners
    max_runners          = var.max_runners
    runner_image         = var.runner_image
    runner_labels        = var.runner_labels
    working_directory    = var.working_directory
  })]

  depends_on = [module.controller_helm]
}
