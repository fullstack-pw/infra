variable "namespace" {
  description = "Namespace for ARC and runners"
  type        = string
  default     = "actions-runner-system"
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
