provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "kubernetes-admin@kubernetes"
}

provider "vault" {
  address = "https://vault.fullstack.pw"
  token   = var.vault_token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "kubernetes-admin@kubernetes"
  }
}