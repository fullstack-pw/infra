---
apiVersion: v1
kind: Namespace
metadata:
  name: ${CLUSTER_NAME}
  labels:
    ephemeral: "true"
    pr: "${PR_NUMBER}"
    repo: "${REPOSITORY}"
    cluster-secrets: "true"

---
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAME}
  labels:
    ephemeral: "true"
    pr: "${PR_NUMBER}"
    repo: "${REPOSITORY}"
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 10.244.0.0/16
    services:
      cidrBlocks:
        - 10.96.0.0/12
  controlPlaneEndpoint:
    host: ${CLUSTER_IP}
    port: 6443
  controlPlaneRef:
    apiGroup: controlplane.cluster.x-k8s.io
    kind: KThreesControlPlane
    name: ${CLUSTER_NAME}-cp
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: ProxmoxCluster
    name: ${CLUSTER_NAME}

---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxCluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAME}
  labels:
    cluster.x-k8s.io/cluster-name: ${CLUSTER_NAME}
spec:
  allowedNodes:
    - node03
  controlPlaneEndpoint:
    host: ${CLUSTER_IP}
    port: 6443
  credentialsRef:
    name: proxmox-credentials
  dnsServers:
    - 192.168.1.3
  ipv4Config:
    addresses:
      - ${NODE_IP}-${NODE_IP}
    gateway: 192.168.1.1
    prefix: 24
    metric: 100
  schedulerHints:
    memoryAdjustment: 0

---
apiVersion: controlplane.cluster.x-k8s.io/v1beta2
kind: KThreesControlPlane
metadata:
  name: ${CLUSTER_NAME}-cp
  namespace: ${CLUSTER_NAME}
  labels:
    cluster.x-k8s.io/cluster-name: ${CLUSTER_NAME}
spec:
  replicas: 1
  version: v1.30.6+k3s1
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
      kind: ProxmoxMachineTemplate
      name: ${CLUSTER_NAME}-cp-mt
      namespace: ${CLUSTER_NAME}
    metadata: {}
  kthreesConfigSpec:
    agentConfig:
      kubeletArgs:
        - provider-id=proxmox://{{ ds.meta_data.instance_id }}
      nodeName: '{{ ds.meta_data.local_hostname }}'
    files:
      - content: |
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
                        value: "${CLUSTER_IP}"
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
        owner: root:root
        path: /var/lib/rancher/k3s/server/manifests/kube-vip.yaml
        permissions: "0644"
    preK3sCommands:
      - mkdir -p /home/ubuntu/.ssh
      - chmod 700 /home/ubuntu/.ssh
      - echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+mJj63c+7o+Bu40wNnXwTpXkPTpGJA9OIprmNoljKI pedro@pedro-Legion-5-16IRX9" >> /home/ubuntu/.ssh/authorized_keys
      - chmod 600 /home/ubuntu/.ssh/authorized_keys
      - chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    serverConfig:
      cloudProviderName: external
      disableCloudController: false

---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${CLUSTER_NAME}-cp-mt
  namespace: ${CLUSTER_NAME}
spec:
  template:
    spec:
      sourceNode: node03
      templateID: 9004
      format: qcow2
      full: true
      numCores: 4
      numSockets: 2
      memoryMiB: 16384
      disks:
        bootVolume:
          disk: scsi0
          sizeGb: 20
      network:
        default:
          bridge: vmbr0
          model: virtio
      checks:
        skipCloudInitStatus: true
        skipQemuGuestAgent: true
      metadataSettings:
        providerIDInjection: true
      vmIDRange:
        start: 401
        end: 450
