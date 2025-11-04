# Istiod (Istio Control Plane) Configuration

global:
  # Logging settings
  logging:
    level: "default:info"

pilot:
  # Replica count for high availability
  replicaCount: ${pilot_replicas}

  # Resource requests and limits
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Enable automatic sidecar injection
  enableAutomountServiceAccountToken: true

# Telemetry configuration
telemetry:
  enabled: ${enable_telemetry}

meshConfig:
  # Access logging
  accessLogFile: "${access_log_file}"
  accessLogEncoding: "JSON"

  # Tracing configuration
  enableTracing: ${enable_tracing}
%{ if enable_tracing && tracing_endpoint != "" ~}
  defaultConfig:
    tracing:
      zipkin:
        address: "${tracing_endpoint}"
%{ endif ~}

  # Default namespace for Istio injection
  defaultConfig:
    discoveryAddress: istiod.istio-system.svc:15012
