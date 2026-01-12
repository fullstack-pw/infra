apiVersion: bootstrap.cluster.x-k8s.io/v1beta2
kind: KubeadmConfigTemplate
metadata:
  name: ${worker_kubeadm_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      users:
        - name: ubuntu
          sshAuthorizedKeys:
%{ for key in jsondecode(ssh_authorized_keys) ~}
            - ${key}
%{ endfor ~}
          sudo: ALL=(ALL) NOPASSWD:ALL
      joinConfiguration:
        nodeRegistration:
          criSocket: unix:///var/run/containerd/containerd.sock
          kubeletExtraArgs:
            - name: provider-id
              value: "proxmox://'{{ ds.meta_data.instance_id }}'"
            - name: rotate-server-certificates
              value: "true"
            - name: rotate-certificates
              value: "true"
