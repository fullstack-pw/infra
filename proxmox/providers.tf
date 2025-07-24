terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
  backend "s3" {
    bucket = "terraform"
    key    = "proxmox.tfstate"
    endpoints = {
      s3 = "https://s3.fullstack.pw"
    }
    region                      = "main"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
provider "proxmox" {
  pm_api_url          = "https://192.168.1.248:8006/api2/json"
  pm_user             = "root@pam"
  pm_password         = var.PROXMOX_PASSWORD
  pm_tls_insecure     = true
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
}
