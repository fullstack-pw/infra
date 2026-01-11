apiVersion: controlplane.cluster.x-k8s.io/v1beta2
kind: KubeadmControlPlane
metadata:
  name: ${kubeadm_control_plane_name}
  namespace: ${namespace}
spec:
  version: ${kubernetes_version}
  replicas: ${cp_replicas}
  kubeadmConfigSpec:
    users:
      - name: ubuntu
        sshAuthorizedKeys:
%{ for key in jsondecode(ssh_authorized_keys) ~}
          - ${key}
%{ endfor ~}
        sudo: ALL=(ALL) NOPASSWD:ALL
    clusterConfiguration:
      apiServer:
        certSANs:
          - ${control_plane_endpoint_ip}
          - localhost
          - 127.0.0.1
      controllerManager:
        extraArgs:
          - name: enable-hostpath-provisioner
            value: "true"
    preKubeadmCommands:
      - /etc/kube-vip-prepare.sh
    files:
      - path: /etc/kubernetes/manifests/kube-vip.yaml
        owner: root:root
        permissions: "0644"
        content: |
          apiVersion: v1
          kind: Pod
          metadata:
            creationTimestamp: null
            name: kube-vip
            namespace: kube-system
          spec:
            containers:
            - name: kube-vip
              image: ghcr.io/kube-vip/kube-vip:v1.0.2
              args:
              - manager
              env:
              - name: cp_enable
                value: "true"
              - name: cp_namespace
                value: kube-system
              - name: vip_interface
                value: ""
              - name: vip_arp
                value: "true"
              - name: address
                value: ${control_plane_endpoint_ip}
              - name: port
                value: "6443"
              - name: vip_leaderelection
                value: "true"
              - name: vip_leasename
                value: plndr-cp-lock
              - name: vip_leaseduration
                value: "5"
              - name: vip_renewdeadline
                value: "3"
              - name: vip_retryperiod
                value: "1"
              - name: vip_cidr
                value: "32"
              imagePullPolicy: IfNotPresent
              resources: {}
              securityContext:
                capabilities:
                  add:
                  - NET_ADMIN
                  - NET_RAW
                  - SYS_TIME
              volumeMounts:
              - mountPath: /etc/kubernetes/admin.conf
                name: kubeconfig
            hostAliases:
            - ip: 127.0.0.1
              hostnames:
              - localhost
              - kubernetes
            hostNetwork: true
            volumes:
            - name: kubeconfig
              hostPath:
                path: /etc/kubernetes/admin.conf
                type: FileOrCreate
          status: {}
      - path: /etc/kube-vip-prepare.sh
        owner: root:root
        permissions: "0700"
        content: |
          #!/bin/bash

          # Redirect all output to log file
          exec > /var/log/kube-vip-prepare.log 2>&1

          set -ex
          echo "=== kube-vip-prepare.sh starting at $(date) ==="
          IS_KUBEADM_INIT="false"

          # cloud-init kubeadm init
          echo "Checking for /run/kubeadm/kubeadm.yaml..."
          if [[ -f /run/kubeadm/kubeadm.yaml ]]; then
            echo "Found /run/kubeadm/kubeadm.yaml - this is kubeadm init"
            IS_KUBEADM_INIT="true"
          else
            echo "/run/kubeadm/kubeadm.yaml not found"
          fi

          # ignition kubeadm init
          echo "Checking for /etc/kubeadm.sh with 'kubeadm init'..."
          if [[ -f /etc/kubeadm.sh ]] && grep -q -e "kubeadm init" /etc/kubeadm.sh; then
            echo "Found /etc/kubeadm.sh with 'kubeadm init' - this is kubeadm init"
            IS_KUBEADM_INIT="true"
          else
            echo "/etc/kubeadm.sh check did not match"
          fi

          echo "IS_KUBEADM_INIT=$IS_KUBEADM_INIT"

          if [[ "$IS_KUBEADM_INIT" == "true" ]]; then
            echo "This is kubeadm init - patching kube-vip.yaml hostPath to use super-admin.conf"
            echo "Before patch:"
            grep -n "path.*admin.conf" /etc/kubernetes/manifests/kube-vip.yaml || echo "No admin.conf path references found"

            # Only change the hostPath, NOT the mountPath inside the container
            # The container expects the file at /etc/kubernetes/admin.conf
            # But we mount super-admin.conf from the host to that location
            sed -i 's#path: /etc/kubernetes/admin.conf#path: /etc/kubernetes/super-admin.conf#g' \
              /etc/kubernetes/manifests/kube-vip.yaml

            echo "After patch:"
            grep -n "path.*admin.conf\|path.*super-admin.conf" /etc/kubernetes/manifests/kube-vip.yaml || echo "No conf path references found"
            echo "Patch completed successfully"
          else
            echo "This is NOT kubeadm init - leaving kube-vip.yaml unchanged"
          fi

          echo "=== kube-vip-prepare.sh completed at $(date) ==="
    initConfiguration:
      nodeRegistration:
        criSocket: unix:///var/run/containerd/containerd.sock
        kubeletExtraArgs:
          - name: provider-id
            value: "proxmox://'{{ ds.meta_data.instance_id }}'"
    joinConfiguration:
      nodeRegistration:
        criSocket: unix:///var/run/containerd/containerd.sock
        kubeletExtraArgs:
          - name: provider-id
            value: "proxmox://'{{ ds.meta_data.instance_id }}'"
    postKubeadmCommands:
      - kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f ${cni_manifest_url}
  machineTemplate:
    spec:
      infrastructureRef:
        apiGroup: infrastructure.cluster.x-k8s.io
        kind: ProxmoxMachineTemplate
        name: ${control_plane_template_name}
