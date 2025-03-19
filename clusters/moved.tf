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

/**
 * Moved blocks for GitHub Runner module refactoring
 */

# Moved blocks for namespace
moved {
  from = module.github_runner[0].kubernetes_namespace.arc_namespace
  to   = module.github_runner[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for credentials
moved {
  from = module.github_runner[0].kubernetes_secret.github_pat
  to   = module.github_runner[0].module.credentials.kubernetes_secret.this[0]
}

moved {
  from = module.github_runner[0].kubernetes_secret.kubeconfig
  to   = module.github_runner[0].module.kubeconfig_secret.kubernetes_secret.this[0]
}


# Moved blocks for Helm release
moved {
  from = module.github_runner[0].helm_release.arc
  to   = module.github_runner[0].module.helm.helm_release.this
}

/**
 * Moved blocks for OpenTelemetry Collector refactoring
 */

# Moved blocks for namespace
moved {
  from = kubernetes_namespace.observability[0]
  to   = module.otel_collector[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for Helm release
moved {
  from = helm_release.opentelemetry_collector[0]
  to   = module.otel_collector[0].module.helm.helm_release.this
}

/**
 * Moved blocks for GitLab Runner module refactoring
 */

# Moved blocks for namespace
moved {
  from = module.gitlab_runner[0].kubernetes_namespace.gitlab
  to   = module.gitlab_runner[0].module.namespace.kubernetes_namespace.this[0]
}


# Moved blocks for kubeconfig secret
moved {
  from = module.gitlab_runner[0].kubernetes_secret.kubeconfig
  to   = module.gitlab_runner[0].module.kubeconfig_secret.kubernetes_secret.this[0]
}

# Moved blocks for Helm release
moved {
  from = module.gitlab_runner[0].helm_release.gitlab_runner
  to   = module.gitlab_runner[0].module.helm.helm_release.this
}

/**
 * Moved blocks for OpenTelemetry Collector refactoring
 */

# Moved blocks for namespace
moved {
  from = kubernetes_namespace.observability[0]
  to   = module.otel_collector[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for Helm release
moved {
  from = helm_release.opentelemetry_collector[0]
  to   = module.otel_collector[0].module.helm.helm_release.this
}

/**
 * Moved blocks for Observability module refactoring
 */

# Moved blocks for namespace - need to check this one
moved {
  from = module.observability[0].kubernetes_namespace.observability
  to   = module.observability[0].module.namespace.kubernetes_namespace.this[0]
}

# Moved blocks for OpenTelemetry Operator
moved {
  from = module.observability[0].helm_release.opentelemetry_operator
  to   = module.observability[0].module.otel_operator.helm_release.this
}

# Moved blocks for Jaeger Operator
moved {
  from = module.observability[0].helm_release.jaeger_operator
  to   = module.observability[0].module.jaeger_operator.helm_release.this
}

# Moved blocks for OTEL Collector ingress
moved {
  from = module.observability[0].kubernetes_ingress_v1.otel_collector_http_ingress
  to   = module.observability[0].module.otel_collector_http_ingress.kubernetes_ingress_v1.this[0]
}

# Moved blocks for Jaeger ingress
moved {
  from = module.observability[0].kubernetes_ingress_v1.jaeger_ingress
  to   = module.observability[0].module.jaeger_ingress.kubernetes_ingress_v1.this[0]
}

# Moved blocks for Prometheus
moved {
  from = module.observability[0].helm_release.prometheus[0]
  to   = module.observability[0].module.prometheus[0].helm_release.this
}
