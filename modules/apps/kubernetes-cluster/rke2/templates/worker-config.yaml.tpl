apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: RKE2ConfigTemplate
metadata:
  name: ${worker_rke2_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      agentConfig:
        version: ${kubernetes_version}
