terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

resource "kubernetes_manifest" "database" {
  count = var.create ? 1 : 0

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Database"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = merge(
      {
        name  = var.database_name
        owner = var.owner
        cluster = {
          name = var.cluster_name
        }
      },
      var.reclaim_policy != null ? {
        databaseReclaimPolicy = var.reclaim_policy
      } : {},
      var.ensure != "present" ? {
        ensure = var.ensure
      } : {},
      var.encoding != null ? {
        encoding = var.encoding
      } : {},
      var.locale_collate != null ? {
        localeCollate = var.locale_collate
      } : {},
      var.locale_ctype != null ? {
        localeCType = var.locale_ctype
      } : {},
      var.is_template != null ? {
        isTemplate = var.is_template
      } : {},
      var.template != null ? {
        template = var.template
      } : {}
    )
  }
}
