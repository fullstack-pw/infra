apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: RKE2ControlPlane
metadata:
  name: ${rke2_control_plane_name}
  namespace: ${namespace}
spec:
  replicas: ${cp_replicas}
  version: ${rke2_version}
  registrationMethod: ${rke2_registration_method}
  registrationAddress: ${control_plane_endpoint_ip}
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
  serverConfig:
    cni: ${rke2_cni}
%{ if length(jsondecode(disable_rke2_components)) > 0 ~}
    disableComponents:
      kubeProxy: false
      scheduler: false
      cloudController: false
%{ endif ~}
%{ if length(jsondecode(rke2_server_args)) > 0 ~}
    additionalUserData:
      config: |
        server-args:
%{ for arg in jsondecode(rke2_server_args) ~}
          - ${arg}
%{ endfor ~}
%{ endif ~}
  preRKE2Commands:
    - mkdir -p /home/ubuntu/.ssh
    - chmod 700 /home/ubuntu/.ssh
%{ for key in jsondecode(ssh_authorized_keys) ~}
    - echo "${key}" >> /home/ubuntu/.ssh/authorized_keys
%{ endfor ~}
    - chmod 600 /home/ubuntu/.ssh/authorized_keys
    - chown -R ubuntu:ubuntu /home/ubuntu/.ssh
  files:
    - path: /etc/rancher/rke2/config.yaml.d/99-kube-vip.yaml
      owner: root:root
      permissions: "0644"
      content: |
        kube-apiserver-arg:
          - anonymous-auth=true
    - path: /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
      owner: root:root
      permissions: "0644"
      content: |
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: kube-vip
          namespace: kube-system
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: kube-vip-role
        rules:
          - apiGroups: [""]
            resources: ["services", "endpoints", "nodes"]
            verbs: ["list", "get", "watch"]
          - apiGroups: [""]
            resources: ["services/status"]
            verbs: ["update"]
          - apiGroups: ["coordination.k8s.io"]
            resources: ["leases"]
            verbs: ["list", "get", "watch", "update", "create"]
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: kube-vip-binding
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: kube-vip-role
        subjects:
          - kind: ServiceAccount
            name: kube-vip
            namespace: kube-system
        ---
        apiVersion: apps/v1
        kind: DaemonSet
        metadata:
          name: kube-vip
          namespace: kube-system
        spec:
          selector:
            matchLabels:
              app: kube-vip
          template:
            metadata:
              labels:
                app: kube-vip
            spec:
              serviceAccountName: kube-vip
              hostNetwork: true
              containers:
                - name: kube-vip
                  image: ghcr.io/kube-vip/kube-vip:v0.8.7
                  imagePullPolicy: IfNotPresent
                  args:
                    - manager
                  env:
                    - name: vip_arp
                      value: "true"
                    - name: address
                      value: "${control_plane_endpoint_ip}"
                    - name: port
                      value: "6443"
                    - name: vip_cidr
                      value: "32"
                    - name: cp_enable
                      value: "true"
                    - name: cp_namespace
                      value: kube-system
                    - name: vip_leaderelection
                      value: "true"
                    - name: vip_leasename
                      value: plndr-cp-lock
                    - name: vip_leaseduration
                      value: "15"
                    - name: vip_renewdeadline
                      value: "10"
                    - name: vip_retryperiod
                      value: "2"
                  securityContext:
                    capabilities:
                      add:
                        - NET_ADMIN
                        - NET_RAW
              nodeSelector:
                node-role.kubernetes.io/control-plane: "true"
              tolerations:
                - effect: NoSchedule
                  key: node-role.kubernetes.io/control-plane
                  operator: Exists
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
      kind: ProxmoxMachineTemplate
      name: ${control_plane_template_name}
  rolloutStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
