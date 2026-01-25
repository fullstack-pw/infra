apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: K0sWorkerConfigTemplate
metadata:
  name: ${worker_k0s_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      version: ${kubernetes_version}
      preInstalledK0s: true
