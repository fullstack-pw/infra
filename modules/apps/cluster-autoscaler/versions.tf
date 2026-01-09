terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.15"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17"
    }
  }
}
