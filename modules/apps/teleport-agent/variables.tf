variable "namespace" {
  description = "Kubernetes namespace for Teleport agent"
  type        = string
  default     = "teleport-agent"
}

variable "roles" {
  default = "kube,app,db"
}

variable "apps" {
  description = "Map of applications to register with Teleport"
  type        = map(string)
  default     = {}
}

variable "databases" {
  description = "Map of applications to register with Teleport"
  type        = map(string)
  default     = {}
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "teleport-agent"
}

variable "chart_version" {
  description = "Teleport Agent Helm chart version"
  type        = string
  default     = "17.7.1"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 300
}

variable "cluster_name" {
  description = "Name of the Teleport cluster"
  type        = string
  default     = "fullstack-pw"
}

variable "teleport_version" {
  description = "Teleport version"
  type        = string
  default     = "17.7.1"
}

variable "proxy_server" {
  description = "Teleport proxy server address"
  type        = string
  default     = "teleport.fullstack.pw:3080"
}

variable "join_token" {
  description = "Teleport join token for the agent"
  type        = string
  sensitive   = true
}

variable "ca_pin" {
  description = "Teleport CA pin for validation"
  type        = string
  default     = ""
}

variable "ssl_ca_cert_key" {
  default = "SSL_CA"
}
variable "kubernetes_cluster_name" {
  description = "Name of the Kubernetes cluster this agent is deployed to"
  type        = string
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Teleport agent log level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "Log level must be DEBUG, INFO, WARN, or ERROR."
  }
}

variable "node_selector" {
  description = "Node selector for agent pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Tolerations for agent pods"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}

variable "resources" {
  description = "Resource requests and limits for agent pods"
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
      memory = "256Mi"
    }
  }
}

variable "create_limited_role" {
  description = "Create a limited ClusterRole for restricted access"
  type        = bool
  default     = true
}

variable "additional_set_values" {
  description = "Additional values to set in the Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
