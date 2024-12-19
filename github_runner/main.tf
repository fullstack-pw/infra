# Fetch the GitHub token from Vault
data "vault_kv_secret_v2" "github_token" {
  mount = "kv"            # Adjust to your Vault KV mount name
  name  = "github-runner" # Path to the secret in Vault
}

# Create a namespace for the GitHub runner
resource "kubernetes_namespace" "github_runner" {
  metadata {
    name = "github-runner"
  }
}

# Store the GitHub token in a Kubernetes secret
resource "kubernetes_secret" "github_runner_secret" {
  metadata {
    name      = "github-runner-secret"
    namespace = kubernetes_namespace.github_runner.metadata[0].name
  }

  data = {
    GITHUB_OWNER = var.github_owner
    GITHUB_REPO  = var.github_repo
    GITHUB_TOKEN = data.vault_kv_secret_v2.github_token.data["token"]
    GITHUB_PAT   = data.vault_kv_secret_v2.github_token.data["GITHUB_PAT"]
  }
}

# Create a Kubernetes Service Account
resource "kubernetes_service_account" "github_runner" {
  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.github_runner.metadata[0].name
  }
}

# Deploy the GitHub Actions runner pod
resource "kubernetes_deployment" "github_runner" {
  metadata {
    name      = "github-runner"
    namespace = kubernetes_namespace.github_runner.metadata[0].name
    labels = {
      app = "github-runner"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "github-runner"
      }
    }

    template {
      metadata {
        labels = {
          app = "github-runner"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.github_runner.metadata[0].name

        # Main GitHub Runner Container
        container {
          name              = "github-runner"
          image             = docker_image.custom_github_runner.image_id
          image_pull_policy = "Never"

          env {
            name  = "GITHUB_URL"
            value = "https://github.com/${var.github_owner}"
          }

          env {
            name = "RUNNER_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.github_runner_secret.metadata[0].name
                key  = "GITHUB_TOKEN"
              }
            }
          }

          env {
            name  = "RUNNER_NAME"
            value = var.runner_name
          }

          env {
            name  = "RUNNER_WORKDIR"
            value = "/tmp/github-runner"
          }

          env {
            name  = "GITHUB_API_URL"
            value = "https://api.github.com/orgs/${var.github_owner}"
          }

          env {
            name = "GITHUB_PAT"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.github_runner_secret.metadata[0].name
                key  = "GITHUB_PAT"
              }
            }
          }

          env {
            name  = "DOCKER_HOST"
            value = "tcp://localhost:2375"
          }

          volume_mount {
            name       = "runner-workdir"
            mount_path = "/tmp/github-runner"
          }

          # Share DinD socket with the runner container
          volume_mount {
            name       = "dind-socket"
            mount_path = "/var/run/docker.sock"
          }
        }

        # DinD Rootless Container
        container {
          name  = "dind"
          image = "docker:dind-rootless"

          security_context {
            privileged = true
          }

          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = ""
          }

          env {
            name  = "DOCKER_HOST"
            value = "unix:///var/run/docker.sock"
          }

          volume_mount {
            name       = "dind-socket"
            mount_path = "/var/run/docker.sock"
          }
        }

        # Volumes for Runner and DinD
        volume {
          name = "runner-workdir"
          empty_dir {}
        }

        volume {
          name = "dind-socket"
          empty_dir {}
        }
      }
    }
  }
  depends_on = [docker_image.custom_github_runner]
}

# Build Docker image locally
resource "docker_image" "custom_github_runner" {
  name = "custom-github-runner:${sha1(join("", [for f in fileset(path.module, "docker_image/*") : filesha1(f)]))}"

  build {
    context    = "./docker_image" # Path to the Dockerfile directory
    dockerfile = "Dockerfile"
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "docker_image/*") : filesha1(f)]))
  }
  lifecycle {
    create_before_destroy = true
  }

}
