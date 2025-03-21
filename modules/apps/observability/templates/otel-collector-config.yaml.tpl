receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
  prometheus:
    config:
      scrape_configs:
        - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          job_name: integrations/kubernetes/cadvisor
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - replacement: kubernetes.default.svc.cluster.local:443
              target_label: __address__
            - regex: (.+)
              replacement: /api/v1/nodes/$${1}/proxy/metrics/cadvisor
              source_labels:
                - __meta_kubernetes_node_name
              target_label: __metrics_path__
          metric_relabel_configs:
            - source_labels: [__name__]
              action: keep
              regex: 'container_cpu_cfs_periods_total|container_cpu_cfs_throttled_periods_total|container_cpu_usage_seconds_total|container_fs_reads_bytes_total|container_fs_reads_total|container_fs_writes_bytes_total|container_fs_writes_total|container_memory_cache|container_memory_rss|container_memory_swap|container_memory_working_set_bytes|container_network_receive_bytes_total|container_network_receive_packets_dropped_total|container_network_receive_packets_total|container_network_transmit_bytes_total|container_network_transmit_packets_dropped_total|container_network_transmit_packets_total|machine_memory_bytes'
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: false
            server_name: kubernetes

        - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          job_name: integrations/kubernetes/kubelet
          kubernetes_sd_configs:
            - role: node
          relabel_configs:
            - replacement: kubernetes.default.svc.cluster.local:443
              target_label: __address__
            - regex: (.+)
              replacement: /api/v1/nodes/$${1}/proxy/metrics
              source_labels:
                - __meta_kubernetes_node_name
              target_label: __metrics_path__
          metric_relabel_configs:
            - source_labels: [__name__]
              action: keep
              regex: 'container_cpu_usage_seconds_total|kubelet_certificate_manager_client_expiration_renew_errors|kubelet_certificate_manager_client_ttl_seconds|kubelet_certificate_manager_server_ttl_seconds|kubelet_cgroup_manager_duration_seconds_bucket|kubelet_cgroup_manager_duration_seconds_count|kubelet_node_config_error|kubelet_node_name|kubelet_pleg_relist_duration_seconds_bucket|kubelet_pleg_relist_duration_seconds_count|kubelet_pleg_relist_interval_seconds_bucket|kubelet_pod_start_duration_seconds_bucket|kubelet_pod_start_duration_seconds_count|kubelet_pod_worker_duration_seconds_bucket|kubelet_pod_worker_duration_seconds_count|kubelet_running_container_count|kubelet_running_containers|kubelet_running_pod_count|kubelet_running_pods|kubelet_runtime_operations_errors_total|kubelet_runtime_operations_total|kubelet_server_expiration_renew_errors|kubelet_volume_stats_available_bytes|kubelet_volume_stats_capacity_bytes|kubelet_volume_stats_inodes|kubelet_volume_stats_inodes_used|kubernetes_build_info|namespace_workload_pod|rest_client_requests_total|storage_operation_duration_seconds_count|storage_operation_errors_total|volume_manager_total_volumes'
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            insecure_skip_verify: false
            server_name: kubernetes

        - job_name: integrations/kubernetes/kube-state-metrics
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - action: keep
              regex: kube-state-metrics
              source_labels:
                - __meta_kubernetes_pod_label_app_kubernetes_io_name
          metric_relabel_configs:
            - source_labels: [__name__]
              action: keep
              regex: 'kube_daemonset.*|kube_deployment_metadata_generation|kube_deployment_spec_replicas|kube_deployment_status_observed_generation|kube_deployment_status_replicas_available|kube_deployment_status_replicas_updated|kube_horizontalpodautoscaler_spec_max_replicas|kube_horizontalpodautoscaler_spec_min_replicas|kube_horizontalpodautoscaler_status_current_replicas|kube_horizontalpodautoscaler_status_desired_replicas|kube_job.*|kube_namespace_status_phase|kube_node.*|kube_persistentvolumeclaim_resource_requests_storage_bytes|kube_pod_container_info|kube_pod_container_resource_limits|kube_pod_container_resource_requests|kube_pod_container_status_last_terminated_reason|kube_pod_container_status_restarts_total|kube_pod_container_status_waiting_reason|kube_pod_info|kube_pod_owner|kube_pod_start_time|kube_pod_status_phase|kube_pod_status_reason|kube_replicaset.*|kube_resourcequota|kube_statefulset.*'

        - job_name: integrations/node_exporter
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - action: keep
              regex: prometheus-node-exporter.*
              source_labels:
                - __meta_kubernetes_pod_label_app_kubernetes_io_name
            - action: replace
              source_labels:
                - __meta_kubernetes_pod_node_name
              target_label: instance
            - action: replace
              source_labels:
                - __meta_kubernetes_namespace
              target_label: namespace
          metric_relabel_configs:
            - source_labels: [__name__]
              action: keep
              regex: 'node_cpu.*|node_exporter_build_info|node_filesystem.*|node_memory.*|process_cpu_seconds_total|process_resident_memory_bytes'

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25

exporters:
  logging:
    loglevel: info
  otlp:
    endpoint: ${jaeger_endpoint}
    tls:
      insecure: true
  otlphttp:
    endpoint: https://loki.fullstack.pw/otlp
  prometheus:
    endpoint: 0.0.0.0:8889
    namespace: observability

# Added extensions section for health checks
extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  pipelines:
    traces:
      receivers: [otlp, jaeger]
      processors: [memory_limiter, batch]
      exporters: [otlp, logging]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch]
      exporters: [prometheus, logging]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp, logging]
  extensions: [health_check]