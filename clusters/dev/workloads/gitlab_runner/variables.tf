variable "vault_address" {
  description = "Vault address"
  type        = string
  default     = "https://vault.yourdomain.com"
}

variable "gitlab_runner_concurrent" {
  description = "Number of concurrent runners"
  type        = number
  default     = 10
}

variable "vault_token" {}
