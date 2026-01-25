apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
kind: TalosConfigTemplate
metadata:
  name: ${worker_talos_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      generateType: worker
      configPatches:
        - op: replace
          path: /machine/install
          value:
            disk: ${install_disk}
        - op: add
          path: /machine/kubelet/extraArgs
          value:
            cloud-provider: external
        - op: add
          path: /machine/kubelet/extraArgs/rotate-server-certificates
          value: "true"
