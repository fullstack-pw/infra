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
  app_user_password = var.create_app_user && var.app_user_generate_password ? random_password.app_user_password[0].result : ""
  postgres_password = var.postgres_generate_password ? random_password.postgres_password[0].result : var.postgres_password

  additional_databases_sql = [for db in var.additional_databases : "CREATE DATABASE ${db};"]

  app_user_sql = var.create_app_user ? [
    "CREATE USER ${var.app_username} WITH PASSWORD '${local.app_user_password}';",
    "GRANT ALL PRIVILEGES ON DATABASE ${var.postgres_database} TO ${var.app_username};",
    "GRANT ALL PRIVILEGES ON SCHEMA public TO ${var.app_username};",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${var.app_username};",
    "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${var.app_username};",
  ] : []

  additional_users_sql = flatten([
    for user in var.additional_users : concat(
      ["CREATE USER ${user.username} WITH PASSWORD '${user.password}' REPLICATION;"],
      [for db in user.databases : "GRANT ALL PRIVILEGES ON DATABASE ${db} TO ${user.username};"]
    )
  ])

  all_init_sql  = concat(local.additional_databases_sql, local.app_user_sql, local.additional_users_sql)
  post_init_sql = length(local.all_init_sql) > 0 ? local.all_init_sql : null
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
  count = var.use_custom_server_certs && var.create_cluster && var.ssl_server_cert == "" ? 1 : 0

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

# SSL certificates secret (only if custom server certs are provided)
resource "kubernetes_secret" "ssl_certs" {
  count = var.use_custom_server_certs && var.create_cluster ? 1 : 0

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

        pg_hba = var.enable_ssl ? concat(
          [
            "local   all             all                                     scram-sha-256",
            "host    all             all             127.0.0.1/32            scram-sha-256",
            "host    all             all             ::1/128                 scram-sha-256",
            "hostssl all             ${var.app_username}         10.42.0.0/16            scram-sha-256",
            "hostssl all             ${var.app_username}         10.43.0.0/16            scram-sha-256",
          ],
          var.require_cert_auth_for_admin ? [
            "hostssl all             ${var.postgres_username}           0.0.0.0/0               cert clientcert=verify-full",
            "hostssl all             ${var.postgres_username}           ::/0                    cert clientcert=verify-full",
          ] : [],
          [
            "hostssl all             all             0.0.0.0/0               scram-sha-256",
            "hostssl all             all             ::/0                    scram-sha-256",
          ]
          ) : [
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
          postInitSQL = local.post_init_sql
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

      # SSL certificates from secret (only if using custom server certs)
      # When use_custom_server_certs=false, CNPG manages its own server certificates
      certificates = var.use_custom_server_certs ? {
        serverTLSSecret = kubernetes_secret.ssl_certs[0].metadata[0].name
        serverCASecret  = kubernetes_secret.ssl_certs[0].metadata[0].name
      } : null

      # Managed services for external access via LoadBalancer
      managed = var.ingress_enabled && !var.use_istio ? {
        services = {
          additional = [
            {
              selectorType = "rw"
              serviceTemplate = {
                metadata = {
                  name = "${var.cluster_name}-lb"
                  annotations = {
                    "external-dns.alpha.kubernetes.io/hostname" = var.ingress_host
                  }
                }
                spec = {
                  type = "LoadBalancer"
                }
              }
            }
          ]
        }
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

resource "terraform_data" "append_client_ca" {
  count = var.create_cluster && length(var.additional_client_ca_certs) > 0 ? 1 : 0

  triggers_replace = {
    cluster_name     = var.cluster_name
    namespace        = var.namespace
    additional_certs = sha256(join("\n", var.additional_client_ca_certs))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e

      # Wait for CNPG to create the CA secret
      echo "Waiting for ${var.cluster_name}-ca secret..."
      for i in {1..60}; do
        if kubectl get secret ${var.cluster_name}-ca -n ${var.namespace} >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Get existing CA data
      EXISTING_CA=$(kubectl get secret ${var.cluster_name}-ca -n ${var.namespace} -o jsonpath='{.data.ca\.crt}' | base64 -d)
      EXISTING_KEY=$(kubectl get secret ${var.cluster_name}-ca -n ${var.namespace} -o jsonpath='{.data.ca\.key}' | base64 -d)

      # Extract only the first certificate (CNPG's own CA)
      CNPG_CA=$(echo "$EXISTING_CA" | awk '/-----BEGIN CERTIFICATE-----/{i++}i==1')

      # Create combined CA bundle: CNPG CA + additional client CAs
      COMBINED_CA="$CNPG_CA
${join("\n", var.additional_client_ca_certs)}"

      # Update secret with combined CA
      kubectl create secret generic ${var.cluster_name}-ca \
        --from-literal=ca.crt="$COMBINED_CA" \
        --from-literal=ca.key="$EXISTING_KEY" \
        -n ${var.namespace} \
        --dry-run=client -o yaml | kubectl apply -f -

      # Add reload label so CNPG picks up the change
      kubectl label secret ${var.cluster_name}-ca cnpg.io/reload=true -n ${var.namespace} --overwrite

      echo "Client CA certificates updated in ${var.cluster_name}-ca"
    EOT
  }

  depends_on = [kubernetes_manifest.postgres_cluster]
}

module "ingress" {
  source = "../../base/ingress"

  enabled            = var.ingress_enabled && !var.use_istio
  name               = "${var.cluster_name}-ingress"
  namespace          = var.namespace
  host               = var.ingress_host
  service_name       = "${var.cluster_name}-rw"
  service_port       = var.service_port
  tls_enabled        = var.ingress_tls_enabled
  tls_secret_name    = var.ingress_tls_secret_name
  ingress_class_name = var.ingress_class_name
  cluster_issuer     = var.cert_manager_cluster_issuer
  annotations = merge({
    "nginx.ingress.kubernetes.io/proxy-body-size"       = "50m"
    "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "60"
    "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "60"
    "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "60"
    "nginx.ingress.kubernetes.io/backend-protocol"      = "HTTPS"
    "nginx.ingress.kubernetes.io/ssl-passthrough"       = "true"
  }, var.ingress_annotations)

  depends_on = [kubernetes_namespace.this, kubernetes_manifest.postgres_cluster]
}

module "istio_gateway" {
  source = "../../base/istio-gateway"

  enabled   = var.ingress_enabled && var.istio_CRDs
  name      = "${var.cluster_name}-gateway"
  namespace = var.istio_gateway_namespace
  hosts     = [var.ingress_host]

  http_enabled  = false
  https_enabled = false

  additional_servers = [
    {
      port = {
        number   = 5432
        name     = "tcp-postgres"
        protocol = "TLS"
      }
      hosts = [var.ingress_host]
      tls = {
        mode = "PASSTHROUGH"
      }
    }
  ]

  depends_on = [kubernetes_namespace.this]
}

module "istio_virtualservice" {
  source = "../../base/istio-virtualservice"

  enabled      = var.ingress_enabled && var.istio_CRDs
  name         = "${var.cluster_name}-vs"
  namespace    = var.namespace
  hosts        = [var.ingress_host]
  gateways     = ["${var.istio_gateway_namespace}/${var.cluster_name}-gateway"]
  routing_mode = "tls"

  tls_routes = [
    {
      match = [
        {
          port     = 5432
          sniHosts = [var.ingress_host]
        }
      ]
      route = [
        {
          destination = {
            host = "${var.cluster_name}-rw.${var.namespace}.svc.cluster.local"
            port = {
              number = var.service_port
            }
          }
        }
      ]
    }
  ]

  cluster_issuer = var.cert_manager_cluster_issuer

  depends_on = [module.istio_gateway, kubernetes_namespace.this]
}
