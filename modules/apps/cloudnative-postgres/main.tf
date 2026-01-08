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
  postgres_password = var.postgres_generate_password ? random_password.postgres_password[0].result : var.postgres_password
}

resource "random_password" "postgres_password" {
  count   = var.postgres_generate_password ? 1 : 0
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

data "kubernetes_secret" "cluster_secrets" {
  count = var.use_custom_server_certs && var.create_cluster && var.ssl_server_cert == "" ? 1 : 0

  metadata {
    name      = "cluster-secrets"
    namespace = var.namespace
  }

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_secret" "exported_credentials" {
  count = var.create_cluster && var.export_credentials_to_namespace != "" ? 1 : 0

  metadata {
    name      = var.export_credentials_secret_name
    namespace = var.export_credentials_to_namespace
  }

  data = {
    username = var.app_username
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
  # field_manager {
  #   force_conflicts = true
  # }

  # Ignore fields that are dynamically added by the CloudNativePG operator
  computed_fields = [
    "spec.postgresql.parameters",
    "spec.bootstrap.initdb.postInitSQL",
    "spec.storage.storageClass"
  ]

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

      enableSuperuserAccess = var.enable_superuser_access

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
            "hostssl all             root           0.0.0.0/0               cert clientcert=verify-full",
            "hostssl all             root           ::/0                    cert clientcert=verify-full",
          ] : [],
          [for user in var.cert_auth_users : "hostssl all             ${user}           0.0.0.0/0               cert clientcert=verify-full"],
          [for user in var.cert_auth_users : "hostssl all             ${user}           ::/0                    cert clientcert=verify-full"],
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
        initdb = {}
      }

      storage = merge(
        {
          size = var.persistence_size
        },
        var.storage_class != "" ? { storageClass = var.storage_class } : {}
      )

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

      # Managed section: services for external access and declarative roles
      managed = (var.ingress_enabled && !var.use_istio) || length(var.managed_roles) > 0 ? merge(
        # Services for LoadBalancer access
        var.ingress_enabled && !var.use_istio ? {
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
        } : {},
        # Declarative role management
        length(var.managed_roles) > 0 ? {
          roles = [
            for role in var.managed_roles : merge(
              {
                name    = role.name
                ensure  = role.ensure
                login   = role.login
                inherit = role.inherit
              },
              role.superuser ? { superuser = true } : {},
              role.createdb ? { createdb = true } : {},
              role.createrole ? { createrole = true } : {},
              role.replication ? { replication = true } : {},
              role.bypassrls ? { bypassrls = true } : {},
              role.connection_limit != -1 ? { connectionLimit = role.connection_limit } : {},
              role.valid_until != null ? { validUntil = role.valid_until } : {},
              length(role.in_roles) > 0 ? { inRoles = role.in_roles } : {},
              role.password_secret_name != null ? { passwordSecret = { name = role.password_secret_name } } : {},
              role.disable_password ? { disablePassword = true } : {}
            )
          ]
        } : {}
      ) : null
    }
  }

  depends_on = [kubernetes_secret.ssl_certs]
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

data "kubernetes_secret" "postgres_ca" {
  count = var.export_ca_to_vault && var.create_cluster && length(var.additional_client_ca_certs) > 0 ? 1 : 0

  metadata {
    name      = "${var.cluster_name}-ca"
    namespace = var.namespace
  }

  depends_on = [terraform_data.append_client_ca]
}

resource "vault_kv_secret_v2" "postgres_ca" {
  count = var.export_ca_to_vault && var.create_cluster && length(var.additional_client_ca_certs) > 0 ? 1 : 0
  mount = "kv"
  name  = var.vault_ca_secret_path

  data_json = jsonencode({
    "${var.vault_ca_secret_key}" = data.kubernetes_secret.postgres_ca[0].data["ca.crt"]
  })

  depends_on = [data.kubernetes_secret.postgres_ca]
}
