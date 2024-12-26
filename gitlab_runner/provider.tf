provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "rancher-desktop"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "rancher-desktop"
  }
}

provider "vault" {
  address = "https://vault.fullstack.pw"
  token   = var.vault_token
}
