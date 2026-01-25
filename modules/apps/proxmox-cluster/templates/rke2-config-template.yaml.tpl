apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: RKE2ConfigTemplate
metadata:
  name: ${worker_rke2_config_name}
  namespace: ${namespace}
spec:
  template:
    spec:
      preRKE2Commands:
        - mkdir -p /home/ubuntu/.ssh
        - chmod 700 /home/ubuntu/.ssh
%{ for key in jsondecode(ssh_authorized_keys) ~}
        - echo "${key}" >> /home/ubuntu/.ssh/authorized_keys
%{ endfor ~}
        - chmod 600 /home/ubuntu/.ssh/authorized_keys
        - chown -R ubuntu:ubuntu /home/ubuntu/.ssh
      agentConfig:
        nodeName: '{{ ds.meta_data.local_hostname }}'
        kubelet:
          extraArgs:
            - provider-id=proxmox://{{ ds.meta_data.instance_id }}
%{ if length(jsondecode(rke2_node_labels)) > 0 ~}
        nodeLabels:
%{ for key, value in jsondecode(rke2_node_labels) ~}
          - ${key}=${value}
%{ endfor ~}
%{ endif ~}
%{ if length(jsondecode(rke2_node_taints)) > 0 ~}
        nodeTaints:
%{ for taint in jsondecode(rke2_node_taints) ~}
          - ${taint}
%{ endfor ~}
%{ endif ~}
%{ if length(jsondecode(rke2_agent_args)) > 0 ~}
        additionalUserData:
          config: |
            agent-args:
%{ for arg in jsondecode(rke2_agent_args) ~}
              - ${arg}
%{ endfor ~}
%{ endif ~}
