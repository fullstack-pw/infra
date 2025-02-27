# resource "helm_release" "jenkins" {
#   name      = "jenkins"
#   namespace = "jenkins"
#   force_update = true
#   timeout = 120
#   version = "5.8.5"
#   atomic = true

#   create_namespace = true

#   repository = "https://charts.jenkins.io"
#   chart      = "jenkins"

# values = [ <<-EOF
# controller:
#   initContainerEnv:
#     - name: CASC_VAULT_TOKEN
#       value: ${var.vault_token}
#     - name: CASC_VAULT_URL
#       value: "https://vault.fullstack.pw"
#     - name: CASC_VAULT_PATHS
#       value: kv/data/jenkins
#     - name: CASC_VAULT_ENGINE_VERSION
#       value: "1"
#   containerEnv:
#     - name: CASC_VAULT_TOKEN
#       value: ${var.vault_token}
#     - name: CASC_VAULT_URL
#       value: "https://vault.fullstack.pw"
#     - name: CASC_VAULT_PATHS
#       value: kv/data/jenkins
#     - name: CASC_VAULT_ENGINE_VERSION
#       value: "1"
#   installPlugins:
#     - hashicorp-vault-plugin:latest
#     - kubernetes:latest
#     - workflow-aggregator:latest
#     - git:latest
#     - configuration-as-code:latest
#   JCasC:
#     configScripts:
#       vault-configuration: |
#         unclassified:
#           hashicorpVault:
#             configuration:
#               vaultUrl: "https://vault.fullstack.pw"
#               vaultCredentialId: "vault-token"
#       vault-token: |
#         credentials:
#           system:
#             domainCredentials:
#               - credentials:
#                   - VaultTokenCredential:
#                       id: "vault-token"
#                       description: "Vault token"
#                       scope: GLOBAL
#                       token: "${var.vault_token}"
#       github-pat: |
#         credentials:
#           system:
#             domainCredentials:
#               - credentials:
#                   - string:
#                       id: "github-pat"
#                       scope: GLOBAL
#                       description: "GitHub Personal Access Token from Vault"
#                       secret: "$${kv/data/jenkins/GITHUB_PAT}"
#       # multibranch-job: |
#       #   jobs:
#       #     - script: >
#       #         multibranchPipelineJob('infra-terraform') {
#       #           branchSources {
#       #             github {
#       #               id('gh-infra-terraform')
#       #               repoOwner('fullstack-pw')
#       #               repository('infra')
#       #               scanCredentialsId('github-pat')
#       #               buildOriginBranch(true)
#       #               buildOriginPRMerge(true)
#       #             }
#       #           }
#       #           triggers {
#       #             periodic(5)
#       #           }
#       #           factory {
#       #             workflowBranchProjectFactory {
#       #               scriptPath('Jenkinsfile')
#       #             }
#       #           }
#       #         }
#   ingress:
#     enabled: true
#     apiVersion: "extensions/v1beta1"
#     hostName: "jenkins.fullstack.pw"
#     annotations:
#       kubernetes.io/ingress.class: "nginx"
#       external-dns.alpha.kubernetes.io/hostname: jenkins.fullstack.pw
#       cert-manager.io/cluster-issuer: letsencrypt-prod
# persistence:
#   storageClass: "local-path"
# EOF 
# ]
# }

# resource "vault_kubernetes_auth_backend_role" "jenkins_runner" {
#   backend                          = "kubernetes"
#   role_name                        = "jenkins-role"
#   token_policies                   = [vault_policy.jenkins_secrets.name]
#   bound_service_account_names      = ["jenkins"]
#   bound_service_account_namespaces = ["jenkins"]
# }


# resource "vault_policy" "jenkins_secrets" {
#   name = "jenkins-secrets"

#   policy = <<EOT
#   path "kv/data/jenkins" {
#     capabilities = ["read"]
#   }
#   EOT
# }