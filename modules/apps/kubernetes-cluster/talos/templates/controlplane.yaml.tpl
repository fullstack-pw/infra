apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: TalosControlPlane
metadata:
  name: ${talos_control_plane_name}
  namespace: ${namespace}
spec:
  version: ${kubernetes_version}
  replicas: ${cp_replicas}
  infrastructureTemplate:
    kind: ProxmoxMachineTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    name: ${control_plane_template_name}
    namespace: ${namespace}
  controlPlaneConfig:
    controlplane:
      configPatches:
        - op: replace
          path: /machine/install
          value:
            disk: ${install_disk}
            extensions:
              - image: ${qemu_guest_agent_image}
        - op: add
          path: /machine/install/extraKernelArgs
          value:
            - net.ifnames=0
        - op: add
          path: /machine/network
          value:
            interfaces:
              - interface: eth0
                dhcp: false
                vip:
                  ip: ${control_plane_endpoint_ip}
        - op: add
          path: /machine/kubelet/extraArgs
          value:
            cloud-provider: external
        - op: add
          path: /cluster/externalCloudProvider
          value:
            enabled: true
            manifests:
%{ for manifest in jsondecode(cloud_controller_manifests) ~}
              - ${manifest}
%{ endfor ~}
        - op: add
          path: /machine/kubelet/extraArgs/rotate-server-certificates
          value: "true"
        - op: add
          path: /machine/features/kubernetesTalosAPIAccess
          value:
            enabled: true
            allowedRoles:
              - os:reader
            allowedKubernetesNamespaces:
              - kube-system
      generateType: controlplane
