apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${worker_deployment_name}
  namespace: ${namespace}
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
          apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
          kind: TalosConfigTemplate
          name: ${worker_talos_config_name}
      clusterName: ${cluster_name}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
        kind: ProxmoxMachineTemplate
        name: ${worker_template_name}
      version: ${kubernetes_version}
