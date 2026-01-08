variable "create" {
  description = "Whether to create the database resource"
  type        = bool
  default     = true
}

variable "name" {
  description = "Kubernetes object name for the Database resource"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the CNPG cluster lives"
  type        = string
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "owner" {
  description = "PostgreSQL role that owns the database"
  type        = string
}

variable "cluster_name" {
  description = "Name of the CNPG Cluster resource"
  type        = string
}

variable "reclaim_policy" {
  description = "What happens when Database is deleted: 'retain' or 'delete'"
  type        = string
  default     = "retain"
  validation {
    condition     = var.reclaim_policy == null || contains(["retain", "delete"], var.reclaim_policy)
    error_message = "reclaim_policy must be 'retain' or 'delete'"
  }
}

variable "ensure" {
  description = "Whether database should be 'present' or 'absent'"
  type        = string
  default     = "present"
  validation {
    condition     = contains(["present", "absent"], var.ensure)
    error_message = "ensure must be 'present' or 'absent'"
  }
}

variable "encoding" {
  description = "Database encoding (e.g., 'UTF8')"
  type        = string
  default     = null
}

variable "locale_collate" {
  description = "Database LC_COLLATE setting"
  type        = string
  default     = null
}

variable "locale_ctype" {
  description = "Database LC_CTYPE setting"
  type        = string
  default     = null
}

variable "is_template" {
  description = "Whether database is a template"
  type        = bool
  default     = null
}

variable "template" {
  description = "Template to use for database creation"
  type        = string
  default     = null
}
