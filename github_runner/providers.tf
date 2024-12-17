provider "kubernetes" {
  config_path = "~/.kube/config" # Path to your kubeconfig file
}

provider "vault" {
  address = "http://127.0.0.1:30080"
  token   = var.vault_token
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  # Configuration options
}
