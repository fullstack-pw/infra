variable "namespace" {
  description = "Kubernetes namespace for the Docker Registry"
  type        = string
  default     = "registry"
}

variable "create_namespace" {
  description = "Create the namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "deployment_name" {
  description = "Name of the registry deployment"
  type        = string
  default     = "registry"
}

variable "app_label" {
  description = "Value of the app label for the registry"
  type        = string
  default     = "registry"
}

variable "replicas" {
  description = "Number of registry replicas"
  type        = number
  default     = 1
}

variable "registry_image" {
  description = "Docker image for the registry"
  type        = string
  default     = "registry"
}

variable "registry_image_tag" {
  description = "Docker image tag for the registry"
  type        = string
  default     = "2"
}

variable "container_port" {
  description = "Port that the registry container listens on"
  type        = number
  default     = 5000
}

variable "environment_variables" {
  description = "Environment variables for the registry container"
  type        = map(string)
  default     = {}
}

variable "resources_limits_cpu" {
  description = "CPU limits for registry container"
  type        = string
  default     = "200m"
}

variable "resources_limits_memory" {
  description = "Memory limits for registry container"
  type        = string
  default     = "256Mi"
}

variable "resources_requests_cpu" {
  description = "CPU requests for registry container"
  type        = string
  default     = "100m"
}

variable "resources_requests_memory" {
  description = "Memory requests for registry container"
  type        = string
  default     = "128Mi"
}

variable "service_name" {
  description = "Name of the registry service"
  type        = string
  default     = "registry"
}

variable "service_port" {
  description = "Port that the registry service listens on"
  type        = number
  default     = 5000
}

variable "service_type" {
  description = "Type of Kubernetes service to create"
  type        = string
  default     = "ClusterIP"
}

variable "pvc_name" {
  description = "Name of the registry persistent volume claim"
  type        = string
  default     = "registry-storage"
}

variable "storage_class" {
  description = "Storage class for the registry PVC"
  type        = string
  default     = "local-path"
}

variable "storage_size" {
  description = "Size of the registry PVC"
  type        = string
  default     = "10Gi"
}

variable "create_ingress" {
  description = "Whether to create an ingress for the registry"
  type        = bool
  default     = true
}

variable "ingress_name" {
  description = "Name of the registry ingress"
  type        = string
  default     = "ingress-registry"
}

variable "ingress_host" {
  description = "Host for the registry ingress"
  type        = string
  default     = "registry.fullstack.pw"
}

variable "ingress_class_name" {
  description = "Ingress class name for the registry ingress"
  type        = string
  default     = "nginx"
}

variable "tls_secret_name" {
  description = "Name of the TLS secret for the registry ingress"
  type        = string
  default     = "registry-tls"
}

variable "ingress_annotations" {
  description = "Additional annotations for the registry ingress"
  type        = map(string)
  default     = {}
}
