alertmanager:
  enabled: false
prometheus-pushgateway:
  enabled: false
server:
  remoteWrite:
    - url: "${remote_write_url}"
      queue_config:
        capacity: 2500
        max_samples_per_send: 1000
        batch_send_deadline: "5s"
        max_shards: 200
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