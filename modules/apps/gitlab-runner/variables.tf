variable "namespace" {
  description = "Namespace for GitLab runners"
  type        = string
  default     = "gitlab"
}

variable "service_account_name" {
  description = "Service account name for GitLab runners"
  type        = string
  default     = "gitlab-runner-sa"
}

variable "release_name" {
  description = "Name of the Helm release"
  type        = string
  default     = "gitlab-runner"
}

variable "chart_version" {
  description = "Version of the GitLab Runner Helm chart"
  type        = string
  default     = "0.71.0"
}

variable "timeout" {
  description = "Timeout for Helm operations"
  type        = number
  default     = 120
}

variable "concurrent_runners" {
  description = "Number of concurrent runners"
  type        = number
  default     = 10
}

variable "check_interval" {
  description = "Runner check interval in seconds"
  type        = number
  default     = 30
}

variable "runner_tags" {
  description = "Tags to assign to the GitLab runner"
  type        = string
  default     = "k8s-gitlab-runner"
}

variable "gitlab_url" {
  description = "GitLab instance URL"
  type        = string
  default     = "https://gitlab.com/"
}

variable "privileged" {
  description = "Whether to run containers in privileged mode"
  type        = bool
  default     = true
}

variable "poll_timeout" {
  description = "Poll timeout in seconds"
  type        = number
  default     = 600
}
