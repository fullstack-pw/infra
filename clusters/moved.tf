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
