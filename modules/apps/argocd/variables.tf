variable "namespace" {
  description = "Namespace for Argo CD installation"
  type        = string
  default     = "argocd"
}

variable "argocd_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.7.12"
}

variable "argocd_domain" {
  description = "Domain for Argo CD UI"
  type        = string
}

variable "ingress_enabled" {
  description = "Enable ingress for Argo CD server"
  type        = bool
  default     = true
}

variable "ingress_class_name" {
  description = "Ingress class name (e.g., istio, nginx)"
  type        = string
  default     = "istio"
}

variable "cert_issuer" {
  description = "Cert-manager cluster issuer name"
  type        = string
  default     = "letsencrypt-prod"
}

variable "use_istio" {
  description = "Enable Istio-specific configurations"
  type        = bool
  default     = false
}

variable "admin_password_bcrypt" {
  description = "Bcrypt hashed admin password for Argo CD"
  type        = string
  sensitive   = true
}

variable "application_namespaces" {
  description = "Namespaces where Argo CD can manage applications (* for all)"
  type        = string
  default     = "*"
}

variable "enable_notifications" {
  description = "Enable Argo CD notifications controller"
  type        = bool
  default     = true
}

variable "enable_dex" {
  description = "Enable Dex for SSO authentication"
  type        = bool
  default     = false
}

variable "server_resources" {
  description = "Resource limits for Argo CD server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "repo_server_resources" {
  description = "Resource limits for Argo CD repo server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "controller_resources" {
  description = "Resource limits for Argo CD application controller"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}
