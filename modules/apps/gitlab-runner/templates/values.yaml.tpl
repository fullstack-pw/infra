concurrent: ${concurrent}
checkInterval: ${check_interval}
runnerToken: "${registration_token}"
rbac:
  create: true
runners:
  config: |
    [[runners]]
      tags = ["${runner_tags}"]
      name = "${runner_tags}"
      url = "${gitlab_url}"
      executor = "kubernetes"
      environment = ["FF_USE_ADVANCED_POD_SPEC_CONFIGURATION=true"]
      [runners.kubernetes]
        namespace = "${namespace}"
        privileged = ${privileged}
        poll_timeout = ${poll_timeout}
        service_account = "${service_account_name}"
        [[runners.kubernetes.pod_spec]]
          name = "build envvars"
          patch = '''
            containers:
              - name: build
                volumeMounts:
                  - name: kubeconfig-volume
                    mountPath: "/tmp/kubeconfig"
                    subPath: KUBECONFIG
            volumes:
              - name: kubeconfig-volume
                secret:
                  secretName: kubeconfig
          '''
          patch_type = "strategic"