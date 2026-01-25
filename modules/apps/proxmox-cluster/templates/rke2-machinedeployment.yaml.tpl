apiVersion: cluster.x-k8s.io/v1beta1
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
  template:
    spec:
      clusterName: ${cluster_name}
      version: ${rke2_version}
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: RKE2ConfigTemplate
          name: ${worker_rke2_config_name}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
        kind: ProxmoxMachineTemplate
        name: ${worker_template_name}
