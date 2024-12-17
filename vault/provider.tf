provider "kubernetes" {
  config_path = "~/.kube/config"  # Adjust path as per your cluster configuration
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
