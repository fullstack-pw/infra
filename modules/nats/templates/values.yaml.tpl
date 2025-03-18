## NATS Helm chart values

# Cluster configuration
nats:
  # NATS Server name
  name: ${cluster_name}
  
  # Number of NATS server replicas
  replicas: ${replicas}
  
  # Authentication configuration
  %{if auth_enabled || auth_token_enabled}
  # --- NATS Security ---
  %{if auth_token_enabled}
  # Simple authentication using a token
  token: "${auth_token}"
  %{else}
  # Basic user/password authentication
  config:
    cluster:
        routeURLs:
            user: "${nats_user}"
            password: "${nats_password}"
            useFQDN: true
            k8sClusterDomain: fullstack.pw
  %{endif}
  %{endif}
  
  # Server resource limits
  resources:
    requests:
      cpu: ${cpu_request}
      memory: ${memory_request}
    limits:
      cpu: ${cpu_limit}
      memory: ${memory_limit}
  
  # Monitoring
  %{if monitoring_enabled}
  # Enable the HTTP monitoring endpoints
  http:
    enabled: true
    port: 8222
  %{endif}
  

  # Prometheus metrics
  %{if prometheus_enabled}
  exporter:
    enabled: true
    port: ${prometheus_port}
    image: natsio/prometheus-nats-exporter:latest
    serviceMonitor:
      enabled: false  # Set to true if you have Prometheus Operator
  %{endif}
  
  # WebSocket support
  %{if websocket_enabled}
  websocket:
    enabled: true
    port: ${websocket_port}
  %{endif}

# JetStream configuration
%{if jetstream_enabled}
jetstream:
  enabled: true
  
  # File storage
  fileStorage:
    enabled: ${persistence_enabled}
    %{if persistence_enabled}
    storageClassName: ${storage_class}
    size: ${storage_size}
    %{endif}
  
  # Memory storage
  memStorage:
    enabled: false
    size: 1Gi
%{endif}

# NATS Box (NATS client tooling)
natsBox:
  enabled: true
  image: natsio/nats-box:latest
  
%{if prometheus_enabled}
# Prometheus configuration
prometheus:
  operator:
    enabled: false  # Set to true if you have Prometheus Operator
%{endif}

  # Service configuration
service:
    name: ${release_name}
    port: ${nats_port}
    merge:
        spec:
            type: LoadBalancer