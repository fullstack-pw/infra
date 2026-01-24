apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0smotronControlPlane
metadata:
  name: ${k0smotron_control_plane_name}
  namespace: ${namespace}
spec:
  replicas: ${cp_replicas}
  version: ${kubernetes_version}
  service:
    type: ClusterIP
    apiPort: 6443
    konnectivityPort: 8132
  controllerPlaneFlags:
    - --disable-components=helm
  k0sConfig:
    apiVersion: k0s.k0sproject.io/v1beta1
    kind: ClusterConfig
    metadata:
      name: k0s
    spec:
      api:
        externalAddress: ${control_plane_endpoint_host}
        sans:
          - ${control_plane_endpoint_host}
      network:
        provider: ${cni_type}
        podCIDR: ${pod_cidr}
        serviceCIDR: ${service_cidr}
      extensions:
        helm:
          repositories: []
          charts: []
