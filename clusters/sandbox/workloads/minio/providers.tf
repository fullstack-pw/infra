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

terraform {
  backend "s3" {
    bucket         = "terraform"
    key            = "minio.tfstate"
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