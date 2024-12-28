variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "vault_token" {}
variable "kubernetes_ca_cert" {}
variable "token_reviewer_jwt" {}