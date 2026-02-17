variable "namespace" {
  description = "Namespace for GitHub Runners"
  type        = string
  default     = "github"
}

variable "service_account_name" {
  description = "Service account name for GitHub runners"
  type        = string
  default     = "github-runner"
}

variable "github_token" {
  description = "GitHub PAT token with admin:org scope"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user name"
  type        = string
  default     = "fullstack-pw"
}

variable "controller_chart_version" {
  description = "Version of the gha-runner-scale-set-controller Helm chart"
  type        = string
  default     = "0.13.0"
}

variable "runner_chart_version" {
  description = "Version of the gha-runner-scale-set Helm chart"
  type        = string
  default     = "0.13.0"
}

variable "runner_name" {
  description = "Name for the GitHub runner scale set"
  type        = string
  default     = "github-runner"
}

variable "runner_image" {
  description = "Docker image for GitHub runner"
  type        = string
  default     = "registry.fullstack.pw/library/github-runner:latest"
}

variable "runner_labels" {
  description = "Comma-separated list of labels to assign to the GitHub runner"
  type        = string
  default     = ""
}

variable "working_directory" {
  description = "Working directory for the runner"
  type        = string
  default     = ""
}

variable "min_runners" {
  description = "Minimum number of runners"
  type        = number
  default     = 3
}

variable "max_runners" {
  description = "Maximum number of runners"
  type        = number
  default     = 10
}

variable "controller_additional_set_values" {
  description = "Additional values to set in the controller Helm release"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "enable_buildkit_runners" {
  description = "Whether to deploy a rootless BuildKit runner scale set"
  type        = bool
  default     = false
}

variable "buildkit_runner_name" {
  description = "Name for the BuildKit runner scale set (used as runs-on label)"
  type        = string
  default     = "self-hosted-buildkit"
}

variable "buildkit_image" {
  description = "BuildKit daemon image"
  type        = string
  default     = "moby/buildkit:latest"
}

# Legacy variables kept for backward compatibility
variable "install_crd" {
  description = "[DEPRECATED] Whether to install CRDs - not used with new runner architecture"
  type        = bool
  default     = false
}
