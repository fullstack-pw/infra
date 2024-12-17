variable "github_owner" {
  description = "The GitHub user or organization name"
  type        = string
  default     = "fullstack-pw"
}

variable "github_repo" {
  description = "The repository where the runner will be registered"
  type        = string
  default     = ""
}

variable "vault_path" {
  description = "Path to the Vault secret containing the GitHub token"
  type        = string
  default     = "kv/data/github-runner"
}

variable "vault_token" {}

variable "runner_name" {
  description = "The name of the GitHub Actions runner"
  type        = string
  default     = "vault-k8s-runner"
}
