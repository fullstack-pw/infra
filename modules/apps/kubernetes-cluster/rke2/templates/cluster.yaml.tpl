apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${cluster_name}
  namespace: ${namespace}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 10.244.0.0/16
    services:
      cidrBlocks:
        - 10.96.0.0/12
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: RKE2ControlPlane
    name: ${rke2_control_plane_name}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxCluster
    name: ${proxmox_cluster_name}
