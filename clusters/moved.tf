# Moved blocks for namespace
moved {
  from = kubernetes_namespace.redis[0]
  to   = module.redis.module.namespace.kubernetes_namespace.this[0]
  # Depends on var.create_namespace being true
}

# Moved blocks for Redis credentials
moved {
  from = module.redis.module.credentials.random_password.password[0]
  to   = module.redis[0].module.credentials.random_password.password[0]
  # Depends on var.generate_password being true
}

moved {
  from = module.redis.module.credentials.kubernetes_secret.this[0]
  to   = module.redis[0].module.credentials.kubernetes_secret.this[0]
  # Depends on var.create_credentials_secret being true
}

# Moved blocks for Helm release
moved {
  from = module.redis.module.helm.helm_release.this
  to   = module.redis[0].module.helm.helm_release.this
}

# Moved blocks for ingress
moved {
  from = module.redis.module.ingress.kubernetes_ingress_v1.this[0]
  to   = module.redis[0].module.ingress.kubernetes_ingress_v1.this[0]
  # Depends on var.ingress_enabled being true
}


/**
 * Moved blocks for PostgreSQL module refactoring
 * 
 * These moved blocks ensure a smooth migration from the old module structure
 * to the new composable base module approach without breaking existing state.
 */

# Using the corrected syntax with proper module paths

# Moved blocks for namespace
moved {
  from = module.postgres[0].kubernetes_namespace.postgres[0]
  to   = module.postgres[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for PostgreSQL credentials
moved {
  from = module.postgres[0].random_password.postgres_password[0]
  to   = module.postgres[0].module.credentials.random_password.password[0]
}

moved {
  from = module.postgres[0].kubernetes_secret.postgres_credentials[0]
  to   = module.postgres[0].module.credentials.kubernetes_secret.this[0]
}

# Moved blocks for Helm release
moved {
  from = module.postgres[0].helm_release.postgres
  to   = module.postgres[0].module.helm.helm_release.this
}

# Moved blocks for ingress
moved {
  from = module.postgres[0].kubernetes_ingress_v1.postgres_ingress[0]
  to   = module.postgres[0].module.ingress.kubernetes_ingress_v1.this[0]
}

/**
 * Moved blocks for NATS module refactoring
 */

# Moved blocks for namespace
moved {
  from = module.nats[0].kubernetes_namespace.nats[0]
  to   = module.nats[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for NATS credentials and auth
moved {
  from = module.nats[0].random_password.nats_password[0]
  to   = module.nats[0].module.credentials.random_password.password[0]
}

# moved {
#   from = module.nats[0].random_password.nats_auth_token[0]
#   to   = module.nats[0].random_password.nats_auth_token[0]
# }

moved {
  from = module.nats[0].kubernetes_secret.nats_credentials[0]
  to   = module.nats[0].module.credentials.kubernetes_secret.this[0]
}

# Moved blocks for Helm release
moved {
  from = module.nats[0].helm_release.nats
  to   = module.nats[0].module.helm.helm_release.this
}

# Moved blocks for ingress
moved {
  from = module.nats[0].kubernetes_ingress_v1.nats_ingress[0]
  to   = module.nats[0].module.ingress.kubernetes_ingress_v1.this[0]
}

/**
 * Moved blocks for MinIO module refactoring
 */

# Moved blocks for namespace
moved {
  from = module.minio[0].kubernetes_namespace.minio[0]
  to   = module.minio[0].module.namespace.kubernetes_namespace.this[0]
}

# # Moved blocks for MinIO credentials
# moved {
#   from = module.minio[0].random_password.minio_root_password[0]
#   to   = module.minio[0].random_password.minio_root_password[0]
# }

moved {
  from = module.minio[0].kubernetes_secret.minio_credentials[0]
  to   = module.minio[0].module.credentials.kubernetes_secret.this[0]
}

# Moved blocks for Helm release
moved {
  from = module.minio[0].helm_release.minio
  to   = module.minio[0].module.helm.helm_release.this
}
