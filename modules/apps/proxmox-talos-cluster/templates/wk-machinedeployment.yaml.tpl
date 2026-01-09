apiVersion: cluster.x-k8s.io/v1beta2
kind: MachineDeployment
metadata:
  name: ${worker_deployment_name}
  namespace: ${namespace}
  annotations:
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size=2
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size=4
spec:
  clusterName: ${cluster_name}
  replicas: ${wk_replicas}
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: ${cluster_name}
  template:
    metadata:
      labels:
        cluster.x-k8s.io/cluster-name: ${cluster_name}
    spec:
      bootstrap:
        configRef:
          apiGroup: bootstrap.cluster.x-k8s.io
          kind: TalosConfigTemplate
          name: ${worker_talos_config_name}
      clusterName: ${cluster_name}
      infrastructureRef:
        apiGroup: infrastructure.cluster.x-k8s.io
        kind: ProxmoxMachineTemplate
        name: ${worker_template_name}
      version: ${kubernetes_version}
