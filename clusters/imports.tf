# Terraform Import Blocks for DEV Cluster Recovery
# Run these imports before running terraform plan/apply

# ===== CERT MANAGER MODULE =====

# Cert Manager Namespace
import {
  to = module.cert_manager[0].module.namespace.kubernetes_namespace.this[0]
  id = "cert-manager"
}

# Cert Manager Helm Release
import {
  to = module.cert_manager[0].module.helm.helm_release.this
  id = "cert-manager/cert-manager"
}

# Cert Manager Cloudflare Secret
import {
  to = module.cert_manager[0].module.cloudflare_secret.kubernetes_secret.this[0]
  id = "cert-manager/cloudflare-api-token"
}

# Cert Manager Let's Encrypt ClusterIssuer
import {
  to = module.cert_manager[0].kubernetes_manifest.letsencrypt_issuer[0]
  id = "apiVersion=cert-manager.io/v1,kind=ClusterIssuer,name=letsencrypt-prod"
}

# ===== EXTERNAL SECRETS MODULE =====

# External Secrets Namespace
import {
  to = module.external_secrets[0].module.namespace.kubernetes_namespace.this[0]
  id = "external-secrets"
}

# External Secrets Helm Release
import {
  to = module.external_secrets[0].module.helm.helm_release.this
  id = "external-secrets/external-secrets"
}

# External Secrets Vault Token Secret
import {
  to = module.external_secrets[0].module.vault_token_secret.kubernetes_secret.this[0]
  id = "external-secrets/vault-token"
}

# External Secrets Vault ClusterSecretStore
import {
  to = module.external_secrets[0].kubernetes_manifest.vault_secret_store[0]
  id = "apiVersion=external-secrets.io/v1beta1,kind=ClusterSecretStore,name=vault-backend"
}

# External Secrets ClusterExternalSecret
import {
  to = module.external_secrets[0].kubernetes_manifest.cluster_secrets[0]
  id = "apiVersion=external-secrets.io/v1beta1,kind=ClusterExternalSecret,name=cluster-secrets"
}

# ===== EXTERNAL DNS MODULE =====

# External DNS Namespace
import {
  to = module.externaldns[0].module.namespace.kubernetes_namespace.this[0]
  id = "external-dns"
}

# External DNS ServiceAccount
import {
  to = module.externaldns[0].kubernetes_service_account.externaldns
  id = "external-dns/external-dns"
}

# External DNS ClusterRole
import {
  to = module.externaldns[0].kubernetes_cluster_role.externaldns
  id = "external-dns"
}

# External DNS ClusterRoleBinding
import {
  to = module.externaldns[0].kubernetes_cluster_role_binding.externaldns
  id = "external-dns-viewer"
}

# External DNS Deployment
import {
  to = module.externaldns[0].kubernetes_deployment.externaldns
  id = "external-dns/external-dns"
}
