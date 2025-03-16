resource "kubernetes_namespace" "arc_namespace" {
  metadata {
    name = var.namespace
    labels = {
      # Add label to ensure ClusterExternalSecret targets this namespace
      "kubernetes.io/metadata.name" = var.namespace
    }
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
  timeout    = 120

  # Wait for the external secret to be created
  depends_on = [kubernetes_namespace.arc_namespace]

  values = [
    <<-EOF
    authSecret:
      create: true
      github_token: ${var.github_token}
    installCRDs: true
    certManagerEnabled: ${var.cert_manager_enabled}
    image:
      actionsRunnerRepositoryAndTag: "${var.runner_image}"
    EOF
  ]
}

resource "kubernetes_manifest" "runner_deployment" {
  manifest = yamldecode(templatefile("${path.module}/templates/runner-deployment.yaml.tpl", {
    runner_name          = "github-runner"
    namespace            = kubernetes_namespace.arc_namespace.metadata[0].name
    replicas             = var.runner_replicas
    organization         = var.github_owner
    service_account_name = kubernetes_service_account.github_runner.metadata[0].name
    runner_labels        = var.runner_labels
    image                = var.runner_image_override != "" ? var.runner_image_override : ""
    working_directory    = var.working_directory
  }))

  depends_on = [helm_release.arc]
}

resource "kubernetes_manifest" "runner_autoscaler" {
  count = var.enable_autoscaling ? 1 : 0

  manifest = yamldecode(templatefile("${path.module}/templates/runner-autoscaler.yaml.tpl", {
    autoscaler_name        = "github-runner-autoscaler"
    namespace              = kubernetes_namespace.arc_namespace.metadata[0].name
    runner_deployment_name = "github-runner"
    min_replicas           = var.min_runners
    max_replicas           = var.max_runners
    scale_up_threshold     = var.scale_up_threshold
    scale_down_threshold   = var.scale_down_threshold
    scale_up_factor        = var.scale_up_factor
    scale_down_factor      = var.scale_down_factor
  }))

  depends_on = [kubernetes_manifest.runner_deployment]
}
