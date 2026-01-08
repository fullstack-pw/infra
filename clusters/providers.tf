terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.15"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.20.0"
    }
  }
}

provider "kubectl" {
  config_path    = var.kubeconfig_path
  config_context = var.config[terraform.workspace].kubernetes_context
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
  token   = var.VAULT_TOKEN
}

provider "postgresql" {
  host             = try(var.config[terraform.workspace].postgres_dbs_users.external_host, "localhost")
  port             = 5432
  username         = "postgres"
  password         = try(local.secrets_json["kv/cluster-secret-store/secrets/POSTGRES"]["POSTGRES_PASSWORD"], "")
  sslmode          = "require"
  connect_timeout  = 15
  superuser        = true
  expected_version = "15.0.0"
}
