mode: ${mode}

presets:
  logsCollection:
    enabled: ${logs_collection}

ports:
  otlp:
    enabled: ${otlp_enabled}
    containerPort: ${otlp_port}
    servicePort: ${otlp_port}
    protocol: TCP
  otlp-http:
    enabled: ${otlp_http_enabled}
    containerPort: ${otlp_http_port}
    servicePort: ${otlp_http_port}
    protocol: TCP

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:${otlp_port}
        http:
          endpoint: 0.0.0.0:${otlp_http_port}

  processors:
    batch:
      timeout: 1s
      send_batch_size: 1024
    memory_limiter:
      check_interval: 1s
      limit_percentage: 80
      spike_limit_percentage: 25

  exporters:
    otlphttp/sandbox:
      endpoint: "${exporters_endpoint}"
      tls:
        insecure: ${tls_insecure}
    logging:
      loglevel: ${log_level}

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlphttp/sandbox, logging]
      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlphttp/sandbox, logging]

resources:
  limits:
    cpu: ${cpu_limit}
    memory: ${memory_limit}
  requests:
    cpu: ${cpu_request}
    memory: ${memory_request}