/**
 * Variables for Runner Secrets module
 */

variable "secret_name" {
  description = "Name of the Kubernetes secret for the age key"
  type        = string
  default     = "sops-age-key"
}

variable "namespace" {
  description = "Namespace for the age key secret"
  type        = string
  default     = "default"
}

variable "labels" {
  description = "Labels to apply to the secret"
  type        = map(string)
  default     = {}
}

variable "age_key_content" {
  description = "Content of the age private key"
  type        = string
  sensitive   = true
}

variable "create_github_runner_secret" {
  description = "Whether to create a secret for GitHub Actions runners"
  type        = bool
  default     = false
}

variable "github_runner_namespace" {
  description = "Namespace for GitHub Actions runners"
  type        = string
  default     = "actions-runner-system"
}

variable "create_gitlab_runner_secret" {
  description = "Whether to create a secret for GitLab runners"
  type        = bool
  default     = false
}

variable "gitlab_runner_namespace" {
  description = "Namespace for GitLab runners"
  type        = string
  default     = "gitlab"
}
