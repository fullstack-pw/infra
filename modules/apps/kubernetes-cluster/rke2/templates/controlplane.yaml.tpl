apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: RKE2ControlPlane
metadata:
  name: ${rke2_control_plane_name}
  namespace: ${namespace}
spec:
  replicas: ${cp_replicas}
  version: ${rke2_version}
  serverConfig:
    cni: calico
  agentConfig:
    version: ${rke2_version}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxMachineTemplate
    name: ${control_plane_template_name}
  registrationMethod: ${registration_method}
  rolloutStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
