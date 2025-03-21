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
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [logging]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, logging]
  extensions: [health_check]