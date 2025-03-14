variable "namespace" {
  description = "Namespace for ARC and runners"
  type        = string
  default     = "actions-runner-system"
}

variable "use_existing_secret" {
  description = "Use existing secret for GitHub PAT token from cluster-secrets-es"
  type        = bool
  default     = true
}

variable "github_owner" {
  description = "GitHub organization or user"
  type        = string
  default     = "fullstack-pw"
}

variable "arc_chart_version" {
  description = "Version of the actions-runner-controller Helm chart"
  type        = string
  default     = "0.23.7"
}

variable "runner_image" {
  description = "Docker image for GitHub runner"
  type        = string
  default     = "registry.fullstack.pw/github-runner:latest"
}

variable "runner_image_override" {
  description = "Override for the runner image in the deployment (if different from controller config)"
  type        = string
  default     = ""
}

variable "cert_manager_enabled" {
  description = "Enable cert-manager integration for ARC"
  type        = bool
  default     = false
}

variable "runner_replicas" {
  description = "Number of GitHub runner replicas"
  type        = number
  default     = 2
}

variable "runner_labels" {
  description = "Labels to assign to the GitHub runner"
  type        = string
  default     = ""
}

variable "working_directory" {
  description = "Working directory for the runner"
  type        = string
  default     = ""
}

variable "enable_autoscaling" {
  description = "Enable HorizontalRunnerAutoscaler for GitHub runners"
  type        = bool
  default     = false
}

variable "min_runners" {
  description = "Minimum number of runners when autoscaling is enabled"
  type        = number
  default     = 1
}

variable "max_runners" {
  description = "Maximum number of runners when autoscaling is enabled"
  type        = number
  default     = 5
}

variable "scale_up_threshold" {
  description = "Percentage of busy runners to trigger scale up"
  type        = string
  default     = "0.75"
}

variable "scale_down_threshold" {
  description = "Percentage of busy runners to trigger scale down"
  type        = string
  default     = "0.3"
}

variable "scale_up_factor" {
  description = "Factor to scale up by"
  type        = string
  default     = "1.4"
}

variable "scale_down_factor" {
  description = "Factor to scale down by"
  type        = string
  default     = "0.7"
}
