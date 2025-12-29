terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.0"
    }
  }
}

locals {
  app_user_password     = var.create_app_user && var.app_user_generate_password ? random_password.app_user_password[0].result : ""
  postgres_password     = var.postgres_generate_password ? random_password.postgres_password[0].result : var.postgres_password
}

resource "random_password" "postgres_password" {
  count   = var.postgres_generate_password ? 1 : 0
  length  = 32
  special = true
}

resource "random_password" "app_user_password" {
  count   = var.create_app_user && var.app_user_generate_password ? 1 : 0
  length  = 32
  special = true
}

resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "cluster-secrets" = "true"
    }
  }
}

# Read SSL certificates from cluster-secrets (managed by External Secrets Operator) if not provided directly
data "kubernetes_secret" "cluster_secrets" {
  count = var.enable_ssl && var.create_cluster && var.ssl_server_cert == "" ? 1 : 0

  metadata {
    name      = "cluster-secrets"
    namespace = var.namespace
  }

  depends_on = [kubernetes_namespace.this]
}

# Superuser credentials secret
resource "kubernetes_secret" "superuser" {
  count = var.create_cluster ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-superuser"
    namespace = var.namespace
  }

  data = {
    username = var.postgres_username
    password = local.postgres_password
  }

  depends_on = [kubernetes_namespace.this]
}

# Export credentials to another namespace for app access (uses appuser if available, otherwise admin)
resource "kubernetes_secret" "exported_credentials" {
  count = var.create_cluster && var.export_credentials_to_namespace != "" ? 1 : 0

  metadata {
    name      = var.export_credentials_secret_name
    namespace = var.export_credentials_to_namespace
  }

  data = {
    username = var.create_app_user ? var.app_username : var.postgres_username
    password = var.create_app_user ? local.app_user_password : local.postgres_password
  }
}

# SSL certificates secret (only if SSL is enabled)
resource "kubernetes_secret" "ssl_certs" {
  count = var.enable_ssl && var.create_cluster ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-ssl-certs"
    namespace = var.namespace
  }

  data = {
    "tls.crt" = var.ssl_server_cert != "" ? var.ssl_server_cert : data.kubernetes_secret.cluster_secrets[0].data[var.ssl_server_cert_key]
    "tls.key" = var.ssl_server_key != "" ? var.ssl_server_key : data.kubernetes_secret.cluster_secrets[0].data[var.ssl_server_key_key]
    "ca.crt"  = var.ssl_ca_cert != "" ? var.ssl_ca_cert : data.kubernetes_secret.cluster_secrets[0].data[var.ssl_ca_cert_key]
  }

  depends_on = [kubernetes_namespace.this]
}

# PostgreSQL Cluster CRD
resource "kubernetes_manifest" "postgres_cluster" {
  count = var.create_cluster ? 1 : 0

  # Ignore fields that are dynamically added by the CloudNativePG operator
  computed_fields = ["spec.postgresql.parameters"]

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = var.cluster_name
      namespace = var.namespace
    }
    spec = {
      instances = var.instances

      imageName = "${var.registry}/${var.repository}:${var.pg_version}"

      postgresql = {
        parameters = {
          max_connections = "200"
          shared_buffers  = "256MB"
        }

        pg_hba = var.enable_ssl ? [
          "local   all             all                                     scram-sha-256",
          "host    all             all             127.0.0.1/32            scram-sha-256",
          "host    all             all             ::1/128                 scram-sha-256",
          "hostssl all             ${var.app_username}         10.42.0.0/16            scram-sha-256",
          "hostssl all             ${var.app_username}         10.43.0.0/16            scram-sha-256",
          "hostssl all             ${var.postgres_username}           0.0.0.0/0               cert clientcert=verify-full",
          "hostssl all             ${var.postgres_username}           ::/0                    cert clientcert=verify-full",
          "hostssl all             all             0.0.0.0/0               scram-sha-256",
          "hostssl all             all             ::/0                    scram-sha-256",
        ] : [
          "local   all             all                                     scram-sha-256",
          "host    all             all             0.0.0.0/0               scram-sha-256",
          "host    all             all             ::/0                    scram-sha-256",
        ]
      }

      bootstrap = {
        initdb = {
          database = var.postgres_database
          owner    = var.postgres_username
          secret = {
            name = kubernetes_secret.superuser[0].metadata[0].name
          }
          postInitSQL = var.create_app_user ? [
            "CREATE USER ${var.app_username} WITH PASSWORD '${local.app_user_password}';",
            "GRANT ALL PRIVILEGES ON DATABASE ${var.postgres_database} TO ${var.app_username};",
            "GRANT ALL PRIVILEGES ON SCHEMA public TO ${var.app_username};",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${var.app_username};",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${var.app_username};",
          ] : []
        }
      }

      storage = {
        size         = var.persistence_size
        storageClass = var.storage_class != "" ? var.storage_class : null
      }

      resources = {
        requests = {
          memory = var.memory_request
          cpu    = var.cpu_request
        }
        limits = {
          memory = var.memory_limit
          cpu    = var.cpu_limit
        }
      }

      # SSL certificates from secret
      certificates = var.enable_ssl ? {
        serverTLSSecret = kubernetes_secret.ssl_certs[0].metadata[0].name
        serverCASecret  = kubernetes_secret.ssl_certs[0].metadata[0].name
      } : null
    }
  }

  depends_on = [kubernetes_secret.superuser, kubernetes_secret.ssl_certs]
}

# Store credentials in Vault
resource "vault_kv_secret_v2" "postgres_credentials" {
  count = var.needs_secrets && var.create_cluster ? 1 : 0
  mount = "kv"
  name  = var.vault_secret_path

  data_json = jsonencode(merge(
    {
      POSTGRES_USER     = var.postgres_username
      POSTGRES_PASSWORD = local.postgres_password
      POSTGRES_DB       = var.postgres_database
      POSTGRES_HOST     = "${var.cluster_name}-rw.${var.namespace}.svc.cluster.local"
      POSTGRES_PORT     = "5432"
    },
    var.create_app_user ? {
      POSTGRES_APP_USER     = var.app_username
      POSTGRES_APP_PASSWORD = local.app_user_password
    } : {}
  ))
}
