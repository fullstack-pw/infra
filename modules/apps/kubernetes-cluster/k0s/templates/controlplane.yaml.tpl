apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: K0sControlPlane
metadata:
  name: ${k0s_control_plane_name}
  namespace: ${namespace}
spec:
  replicas: ${cp_replicas}
  version: ${k0s_version}
  k0sConfigSpec:
    k0s:
      apiVersion: k0s.k0sproject.io/v1beta1
      kind: ClusterConfig
      spec:
        api:
          extraArgs:
            anonymous-auth: "true"
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
      kind: ProxmoxMachineTemplate
      name: ${control_plane_template_name}
