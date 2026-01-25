apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${worker_deployment_name}
  namespace: ${namespace}
  annotations:
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size: "${autoscaler_min}"
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size: "${autoscaler_max}"
  labels:
    cluster.x-k8s.io/cluster-name: ${cluster_name}
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
        node-role.kubernetes.io/worker: ""
    spec:
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: K0sWorkerConfigTemplate
          name: ${worker_k0s_config_name}
      clusterName: ${cluster_name}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
        kind: ProxmoxMachineTemplate
        name: ${worker_template_name}
      version: ${kubernetes_version}
