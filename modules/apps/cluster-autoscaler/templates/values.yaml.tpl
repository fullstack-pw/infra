cloudProvider: clusterapi

image:
  tag: ${image_tag}

autoDiscovery:
  clusterName: ${cluster_name}
  namespace: ${cluster_namespace}
  enabled: true

extraArgs:
  cloud-provider: clusterapi
  scale-down-enabled: ${scale_down_enabled}
  scale-down-delay-after-add: ${scale_down_delay_after_add}
  scale-down-unneeded-time: ${scale_down_unneeded_time}
  skip-nodes-with-local-storage: ${skip_nodes_with_local_storage}
  skip-nodes-with-system-pods: ${skip_nodes_with_system_pods}
  balance-similar-node-groups: ${balance_similar_node_groups}
  expander: ${expander}
  kubeconfig: /mnt/kubernetes/all-clusters
  clusterapi-cloud-config-authoritative: true

extraVolumes:
  - name: cluster-secrets
    secret:
      secretName: cluster-secrets
      items:
        - key: KUBECONFIG
          path: all-clusters
      defaultMode: 0444

extraVolumeMounts:
  - name: cluster-secrets
    mountPath: /mnt/kubernetes
    readOnly: true

extraEnv:
  KUBECONFIG: /mnt/kubernetes/all-clusters

replicaCount: ${replicas}

rbac:
  create: true
  serviceAccount:
    create: true
    name: cluster-autoscaler

podAnnotations:
  cluster-autoscaler.kubernetes.io/safe-to-evict: "false"

resources:
  requests:
    cpu: 100m
    memory: 300Mi
  limits:
    cpu: 200m
    memory: 512Mi
