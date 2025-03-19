variable "create_secret" {
  description = "Create the Kubernetes secret"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name of the secret"
  type        = string
}

variable "namespace" {
  description = "Namespace for the secret"
  type        = string
}

variable "labels" {
  description = "Labels for the secret"
  type        = map(string)
  default     = {}
}

variable "data" {
  description = "Data for the secret"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "generate_password" {
  description = "Generate a random password"
  type        = bool
  default     = false
}

variable "password" {
  description = "Password to use (if not generating one)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "password_key" {
  description = "Key to use for the password in the secret"
  type        = string
  default     = "password"
}

variable "include_password" {
  description = "Include password in the secret data"
  type        = bool
  default     = true
}

variable "password_length" {
  description = "Length of the generated password"
  type        = number
  default     = 16
}

variable "password_special" {
  description = "Include special characters in the password"
  type        = bool
  default     = false
}

variable "secret_type" {
  description = "Type of the secret"
  type        = string
  default     = "Opaque"
}
