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
      environment = ["FF_USE_ADVANCED_POD_SPEC_CONFIGURATION=true"]
      [runners.kubernetes]
        namespace = "${namespace}"
        privileged = true
        poll_timeout = 600
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