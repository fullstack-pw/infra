driver:
  kind: ${driver_kind}

tty: true

falco:
  json_output: true
  json_include_output_property: true

metrics:
  enabled: ${metrics_enabled}
  interval: 15m
  outputRule: false
  rulesCountersEnabled: true
  resourceUtilizationEnabled: true
  service:
    create: true
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8765"

resources:
  requests:
    cpu: ${cpu_request}
    memory: ${memory_request}
  limits:
    cpu: ${cpu_limit}
    memory: ${memory_limit}
