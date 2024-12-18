concurrent: 10
checkInterval: 30
runnerToken: "${registration_token}"
rbac:
  create: true
runners:
  config: |
    [[runners]]
      tags = ["k8s-gitlab-runner"]
      name = "k8s-gitlab-runner"
      url = "https://gitlab.com/"
      executor = "kubernetes"
      [runners.kubernetes]
        namespace = "${namespace}"
        privileged = true
        poll_timeout = 600
        service_account = "${service_account_name}"
        [runners.kubernetes.pod_annotations]
          "vault.hashicorp.com/agent-inject" = "true"
          "vault.hashicorp.com/role" = "gitlab-role"
          "vault.hashicorp.com/agent-inject-secret-dummy-test" = "kv/dummy-test"
