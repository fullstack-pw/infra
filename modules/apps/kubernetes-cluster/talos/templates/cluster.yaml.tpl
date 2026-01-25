apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${cluster_name}
  namespace: ${namespace}
spec:
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
    kind: TalosControlPlane
    name: ${talos_control_plane_name}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxCluster
    name: ${proxmox_cluster_name}
