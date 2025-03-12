terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.15"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.config[terraform.workspace].kubernetes_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.config[terraform.workspace].kubernetes_context
  }
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}
