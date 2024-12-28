provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "kubernetes-admin@kubernetes"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "kubernetes-admin@kubernetes"
  }
}
