# // ExternalDNS
# import {
#   for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
#   to       = module.externaldns[0].kubernetes_cluster_role.externaldns
#   id       = contains(local.workload, "externaldns") ? "external-dns" : 0
# }

# import {
#   for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
#   to       = module.externaldns[0].kubernetes_cluster_role_binding.externaldns
#   id       = contains(local.workload, "externaldns") ? "external-dns-viewer" : 0
# }

# import {
#   for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
#   to       = module.externaldns[0].kubernetes_deployment.externaldns
#   id       = contains(local.workload, "externaldns") ? "default/external-dns" : 0
# }

# import {
#   for_each = contains(local.workload, "externaldns") ? toset(["externaldns"]) : toset([])
#   to       = module.externaldns[0].kubernetes_service_account.externaldns
#   id       = contains(local.workload, "externaldns") ? "default/external-dns" : 0
# }

# // CertManager
# import {
#   for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
#   to       = module.cert_manager[0].helm_release.cert_manager
#   id       = "cert-manager/cert-manager"
# }
# import {
#   for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
#   to       = module.cert_manager[0].kubernetes_manifest.letsencrypt_issuer
#   id       = "apiVersion=cert-manager.io/v1,kind=ClusterIssuer,namespace=cert-manager,name=letsencrypt-prod"
# }
# import {
#   for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
#   to       = module.cert_manager[0].kubernetes_namespace.cert_manager
#   id       = "cert-manager"
# }
# import {
#   for_each = contains(local.workload, "cert_manager") ? toset(["cert-manager"]) : toset([])
#   to       = module.cert_manager[0].kubernetes_secret.cloudflare_api_token
#   id       = "cert-manager/cloudflare-api-token"
# }

# // External Secrets
# import {
#   for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
#   to       = module.external_secrets[0].kubernetes_namespace.external_secrets
#   id       = "external-secrets"
# }
# import {
#   for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
#   to       = module.external_secrets[0].helm_release.external_secrets
#   id       = "external-secrets/external-secrets"
# }
# import {
#   for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
#   to       = module.external_secrets[0].kubernetes_manifest.cluster_secrets
#   id       = "apiVersion=external-secrets.io/v1beta1,kind=ClusterExternalSecret,name=cluster-secrets"
# }
# import {
#   for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
#   to       = module.external_secrets[0].kubernetes_manifest.vault_secret_store
#   id       = "apiVersion=external-secrets.io/v1beta1,kind=ClusterSecretStore,name=vault-backend"
# }
# import {
#   for_each = contains(local.workload, "external_secrets") ? toset(["external-secrets"]) : toset([])
#   to       = module.external_secrets[0].kubernetes_secret.vault_token
#   id       = "external-secrets/vault-token"
# }

# // OpenTelemetry Collector
# import {
#   for_each = contains(local.workload, "otel_collector") ? toset(["otel-collector"]) : toset([])
#   to       = kubernetes_namespace.observability[0]
#   id       = "observability"
# }
# import {
#   for_each = contains(local.workload, "otel_collector") ? toset(["otel-collector"]) : toset([])
#   to       = helm_release.opentelemetry_collector[0]
#   id       = "observability/opentelemetry-collector"
# }
# // Import statements for GitLab Runner resources

# import {
#   for_each = contains(local.workload, "gitlab_runner") ? toset(["gitlab_runner"]) : toset([])
#   to = module.gitlab_runner[0].kubernetes_namespace.gitlab
#   id = "gitlab"
#   }
# import {
#   for_each = contains(local.workload, "gitlab_runner") ? toset(["gitlab_runner"]) : toset([])
#   to = module.gitlab_runner[0].kubernetes_service_account.gitlab_runner
#   id = "gitlab/gitlab-runner-sa"
#   }
# import {
#   for_each = contains(local.workload, "gitlab_runner") ? toset(["gitlab_runner"]) : toset([])
#   to = module.gitlab_runner[0].kubernetes_secret.kubeconfig
#   id = "gitlab/kubeconfig"
#   }
# import {
#   for_each = contains(local.workload, "gitlab_runner") ? toset(["gitlab_runner"]) : toset([])
#   to = module.gitlab_runner[0].helm_release.gitlab_runner
#   id = "gitlab/gitlab-runner"
#   }

# // Import statements for GitHub Runner resources

# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].kubernetes_namespace.arc_namespace
#   id = "actions-runner-system"
#   }
# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].kubernetes_service_account.github_runner
#   id = "actions-runner-system/github-runner"
#   }
# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].kubernetes_secret.kubeconfig
#   id = "actions-runner-system/kubeconfig"
#   }
# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].kubernetes_secret.github_pat
#   id = "actions-runner-system/github-pat"
#   }
# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].helm_release.arc
#   id = "actions-runner-system/actions-runner-controller"
#   }
# import {
#   for_each = contains(local.workload, "github_runner") ? toset(["github_runner"]) : toset([])
#   to = module.github_runner[0].kubernetes_manifest.runner_deployment
#   id = "apiVersion=actions.summerwind.dev/v1alpha1,kind=RunnerDeployment,namespace=actions-runner-system,name=github-runner"
#   }
# // MINIO
# import {
#   for_each = contains(local.workload, "minio") ? toset(["minio"]) : toset([])
#   to       = module.minio[0].helm_release.minio
#   id       = "default/minio"
# }

# // OBSERVABILITY
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].helm_release.jaeger_operator
#   id       = "observability/jaeger-operator"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].helm_release.opentelemetry_operator
#   id       = "observability/opentelemetry-operator"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].kubernetes_ingress_v1.jaeger_ingress
#   id       = "observability/jaeger-ingress"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].kubernetes_ingress_v1.otel_collector_ingress
#   id       = "observability/otel-collector-ingress"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].kubernetes_manifest.jaeger_instance
#   id       = "apiVersion=jaegertracing.io/v1,kind=Jaeger,namespace=observability,name=jaeger"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].kubernetes_manifest.otel_collector
#   id       = "apiVersion=opentelemetry.io/v1alpha1,kind=OpenTelemetryCollector,namespace=observability,name=otel-collector"
# }
# import {
#   for_each = contains(local.workload, "observability") ? toset(["observability"]) : toset([])
#   to       = module.observability[0].kubernetes_namespace.observability
#   id       = "observability"
# }

# // REGISTRY
# import {
#   for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
#   to       = module.registry[0].kubernetes_deployment.registry
#   id       = "registry/registry"
# }
# import {
#   for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
#   to       = module.registry[0].kubernetes_ingress_v1.registry_ingress[0]
#   id       = "registry/ingress-registry"
# }
# import {
#   for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
#   to       = module.registry[0].kubernetes_namespace.registry[0]
#   id       = "registry"
# }
# import {
#   for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
#   to       = module.registry[0].kubernetes_persistent_volume_claim.registry_storage
#   id       = "registry/registry-storage"
# }
# import {
#   for_each = contains(local.workload, "registry") ? toset(["registry"]) : toset([])
#   to       = module.registry[0].kubernetes_service.registry
#   id       = "registry/registry"
# }

# // VAULT
# import {
#   for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
#   to       = module.vault[0].helm_release.vault
#   id       = "vault/vault"
# }
# import {
#   for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
#   to       = module.vault[0].kubernetes_namespace.vault[0]
#   id       = "vault"
# }
# import {
#   for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
#   to       = module.vault[0].vault_auth_backend.kubernetes[0]
#   id       = "kubernetes"
# }
# import {
#   for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
#   to       = module.vault[0].vault_kubernetes_auth_backend_config.config[0]
#   id       = "auth/kubernetes/config"
# }
# import {
#   for_each = contains(local.workload, "vault") ? toset(["vault"]) : toset([])
#   to       = module.vault[0].vault_mount.kv[0]
#   id       = "kv"
# }

import {
  to = module.vault[0].vault_kv_secret_v2.initial_secrets["kv/cluster-secrets"]
  id = "kv/data/cluster-secrets"
}
import {
  to = module.vault[0].vault_kv_secret_v2.initial_secrets["kv/github-runner"]
  id = "kv/data/github-runner"
}
import {
  to = module.vault[0].vault_kv_secret_v2.initial_secrets["kv/gitlab-runner"]
  id = "kv/data/gitlab-runner"
}
import {
  to = module.vault[0].vault_kv_secret_v2.initial_secrets["kv/jenkins"]
  id = "kv/data/jenkins"
}
