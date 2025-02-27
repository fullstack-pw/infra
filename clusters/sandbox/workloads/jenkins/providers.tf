provider "kubernetes" {
  config_path = "~/.kube/config" # Path to your kubeconfig file
  config_context = "sandbox"
}

provider "vault" {
  address = "http://vault.fullstack.pw"
  token   = var.vault_token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "sandbox"
  }
}
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
  }
  required_version = ">= 1.3.0"
  backend "s3" {
    bucket         = "terraform"
    key            = "sandbox/jenkins.tfstate"
    endpoints = {
      s3 = "https://s3.fullstack.pw"
    }
    region         = "main"
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
  }
}
