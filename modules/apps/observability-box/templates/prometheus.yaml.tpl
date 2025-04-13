alertmanager:
  enabled: false
prometheus-pushgateway:
  enabled: false
server:
  remoteWrite:
    - url: "${remote_write_url}"
      name: "central-prometheus"
      queue_config:
        capacity: 2500
        max_samples_per_send: 1000
        batch_send_deadline: "5s"
        max_shards: 200
        min_backoff: "1s"
        max_backoff: "1m"
      write_relabel_configs:
        - source_labels: [__name__]
          target_label: cluster
          replacement: "${cluster_name}"
      tls_config:
        insecure_skip_verify: true
  resources:
    limits:
      cpu: ${cpu_limit}
      memory: ${memory_limit}
    requests:
      cpu: ${cpu_request}
      memory: ${memory_request}
serverFiles:
  prometheus.yml:
    scrape_configs:
      - job_name: kubernetes-apiservers
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - source_labels: [__meta_kubernetes_endpoint_port_name]
            action: replace
            target_label: endpoint
          - target_label: cluster
            replacement: ${cluster_name}

      - job_name: kubernetes-nodes
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - source_labels: [__meta_kubernetes_node_name]
            action: replace
            target_label: node
          - target_label: namespace
            replacement: "kube-system"
          - target_label: cluster
            replacement: ${cluster_name}

      - job_name: kubernetes-nodes-cadvisor
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - target_label: __metrics_path__
            replacement: /metrics/cadvisor
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: node
            replacement: $1
          - target_label: namespace
            replacement: "kube-system"
          - target_label: container
            replacement: "kubelet"
          - target_label: service
            replacement: "kubelet"
          - target_label: cluster
            replacement: ${cluster_name}

      - job_name: kubernetes-service-endpoints
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_service_name]
            regex: prometheus-(kube-state-metrics|node-exporter)
            action: drop
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
            action: replace
            target_label: __address__
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
          - source_labels: [__meta_kubernetes_service_label_app]
            action: replace
            target_label: app
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            action: replace
            target_label: container
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: node
          - source_labels: [__meta_kubernetes_endpoint_port_name]
            action: replace
            target_label: endpoint
          - target_label: cluster
            replacement: ${cluster_name}

      - job_name: node-exporter
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_endpoints_name]
            regex: prometheus-node-exporter
            action: keep
          - source_labels: [__meta_kubernetes_endpoint_node_name]
            target_label: node
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            action: replace
            target_label: container
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - target_label: cluster
            replacement: ${cluster_name}

      - job_name: kube-state-metrics
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_endpoints_name]
            regex: prometheus-kube-state-metrics
            action: keep
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            action: replace
            target_label: container
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: service
          - source_labels: [__meta_kubernetes_endpoint_port_name]
            action: replace
            target_label: endpoint
          - target_label: cluster
            replacement: ${cluster_name}