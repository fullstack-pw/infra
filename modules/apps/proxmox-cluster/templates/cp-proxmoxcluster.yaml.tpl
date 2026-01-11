apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxCluster
metadata:
  name: ${proxmox_cluster_name}
  namespace: ${namespace}
spec:
  schedulerHints:
    memoryAdjustment: ${memory_adjustment}
%{ if length(jsondecode(allowed_nodes)) > 0 ~}
  allowedNodes:
%{ for node in jsondecode(allowed_nodes) ~}
    - ${node}
%{ endfor ~}
%{ endif ~}
  controlPlaneEndpoint:
    host: ${control_plane_endpoint_ip}
    port: ${control_plane_endpoint_port}
  dnsServers:
%{ for dns in jsondecode(dns_servers) ~}
    - ${dns}
%{ endfor ~}
  ipv4Config:
    addresses:
      - ${ip_range_start}-${ip_range_end}
    gateway: ${gateway}
    prefix: ${prefix}
  credentialsRef:
    name: "${credentials_ref_name}"