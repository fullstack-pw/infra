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
    additionalUserData:
      data:
        users: "\n- name: suporte\n  ssh_authorized_keys:\n${ssh_authorized_keys}\n  sudo: ALL=(ALL) NOPASSWD:ALL\n"
  preRKE2Commands:
  - 'INSTANCE_ID=$(cloud-init query instance-id) && mkdir -p /etc/rancher/rke2/config.yaml.d && echo "kubelet-arg:" > /etc/rancher/rke2/config.yaml.d/provider-id.yaml && echo "- provider-id=proxmox://$INSTANCE_ID" >> /etc/rancher/rke2/config.yaml.d/provider-id.yaml'
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxMachineTemplate
    name: ${control_plane_template_name}
  registrationMethod: ${registration_method}
  registrationAddress: ${registration_address}
  manifestsConfigMapReference:
    name: ${kube_vip_configmap_name}
    namespace: ${namespace}
  rolloutStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
