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


variable "runner_replicas" {
  description = "Number of runner replicas to start with"
  type        = number
  default     = 2
}

variable "vault_token" {}
