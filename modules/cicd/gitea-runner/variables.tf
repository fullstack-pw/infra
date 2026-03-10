variable "namespace" {
  description = "Namespace for Gitea act-runner"
  type        = string
  default     = "gitea"
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "gitea-runner"
}

variable "chart_version" {
  description = "Version of the act-runner Helm chart"
  type        = string
  default     = "0.1.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 120
}

variable "gitea_url" {
  description = "URL of the Gitea instance"
  type        = string
  default     = "https://git.homelabz.eu"
}

variable "runner_token" {
  description = "Runner registration token from Gitea"
  type        = string
  sensitive   = true
}

variable "runner_name" {
  description = "Name of the runner"
  type        = string
  default     = "k8s-runner"
}

variable "runner_labels" {
  description = "Labels (tags) for the runner"
  type        = string
  default     = "ubuntu-latest:docker://registry.toolz.homelabz.eu/library/runner-base:latest,self-hosted:docker://registry.toolz.homelabz.eu/library/runner-base:latest"
}

variable "replicas" {
  description = "Number of runner replicas"
  type        = number
  default     = 1
}
