apiVersion: cluster.x-k8s.io/v1beta2
kind: MachineDeployment
metadata:
  name: ${worker_deployment_name}
  namespace: ${namespace}
%{ if autoscaler_enabled ~}
  annotations:
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size: "${autoscaler_min}"
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size: "${autoscaler_max}"
%{ endif ~}
spec:
  clusterName: ${cluster_name}
  replicas: ${wk_replicas}
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: ${cluster_name}
  rollout:
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0
  template:
    metadata:
      labels:
        cluster.x-k8s.io/cluster-name: ${cluster_name}
    spec:
      clusterName: ${cluster_name}
      version: ${kubernetes_version}
      bootstrap:
        configRef:
          apiGroup: bootstrap.cluster.x-k8s.io
          kind: K0sWorkerConfigTemplate
          name: ${worker_k0s_config_name}
      infrastructureRef:
        apiGroup: infrastructure.cluster.x-k8s.io
        kind: ProxmoxMachineTemplate
        name: ${worker_template_name}
