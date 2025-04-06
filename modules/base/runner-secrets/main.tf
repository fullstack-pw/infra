/**
 * Runner Secrets Module
 * 
 * This module creates Kubernetes secrets containing the SOPS age key
 * for use by CI/CD runners to decrypt secrets.
 */

resource "kubernetes_secret" "age_key" {
  metadata {
    name      = var.secret_name
    namespace = var.namespace
    labels    = var.labels
  }

  data = {
    "age-key.txt" = var.age_key_content
  }

  type = "Opaque"
}

# Optionally, if using GitHub Actions, create a secret for the runner
resource "kubernetes_secret" "github_runner_age_key" {
  count = var.create_github_runner_secret ? 1 : 0

  metadata {
    name      = "sops-age-key"
    namespace = var.github_runner_namespace
    labels = merge(var.labels, {
      "actions.github.com/use-as-volume" = "true"
    })
  }

  data = {
    "age-key.txt" = var.age_key_content
  }

  type = "Opaque"
}

# Optionally, if using GitLab Runners, create a secret for the runner
resource "kubernetes_secret" "gitlab_runner_age_key" {
  count = var.create_gitlab_runner_secret ? 1 : 0

  metadata {
    name      = "sops-age-key"
    namespace = var.gitlab_runner_namespace
    labels = merge(var.labels, {
      "app" = "gitlab-runner"
    })
  }

  data = {
    "age-key.txt" = var.age_key_content
  }

  type = "Opaque"
}
