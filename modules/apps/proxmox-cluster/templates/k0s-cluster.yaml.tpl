apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${cluster_name}
  namespace: ${namespace}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - ${pod_cidr}
    serviceDomain: cluster.local
    services:
      cidrBlocks:
        - ${service_cidr}
  controlPlaneRef:
    apiGroup: controlplane.cluster.x-k8s.io
    kind: K0smotronControlPlane
    name: ${k0smotron_control_plane_name}
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: ProxmoxCluster
    name: ${proxmox_cluster_name}
