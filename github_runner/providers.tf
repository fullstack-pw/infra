provider "kubernetes" {
  config_path = "~/.kube/config" # Path to your kubeconfig file
}

provider "vault" {
  address = "http://127.0.0.1:30080"
  token   = var.vault_token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.15"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8"
    }
  }
  required_version = ">= 1.3.0"
}
