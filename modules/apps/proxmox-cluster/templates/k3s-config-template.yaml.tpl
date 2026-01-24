apiVersion: bootstrap.cluster.x-k8s.io/v1beta2
kind: KThreesConfigTemplate
metadata:
  name: ${worker_k3s_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      preK3sCommands:
        - mkdir -p /home/ubuntu/.ssh
        - chmod 700 /home/ubuntu/.ssh
%{ for key in jsondecode(ssh_authorized_keys) ~}
        - echo "${key}" >> /home/ubuntu/.ssh/authorized_keys
%{ endfor ~}
        - chmod 600 /home/ubuntu/.ssh/authorized_keys
        - chown -R ubuntu:ubuntu /home/ubuntu/.ssh
      agentConfig:
        nodeName: '{{ ds.meta_data.local_hostname }}'
        kubeletArgs:
          - provider-id=proxmox://{{ ds.meta_data.instance_id }}
%{ if length(jsondecode(node_labels)) > 0 ~}
%{ for key, value in jsondecode(node_labels) ~}
          - node-labels=${key}=${value}
%{ endfor ~}
%{ endif ~}
%{ if length(jsondecode(node_taints)) > 0 ~}
%{ for taint in jsondecode(node_taints) ~}
          - register-with-taints=${taint}
%{ endfor ~}
%{ endif ~}
