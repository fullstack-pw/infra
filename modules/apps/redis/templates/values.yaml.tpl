## Redis Helm chart values
architecture: ${architecture}

auth:
  enabled: ${auth_enabled}
  password: "${redis_password}"
  usePasswordFiles: false

master:
  persistence:
    enabled: ${persistence_enabled}
%{if persistence_enabled && storage_class != ""}
    storageClass: "${storage_class}"
%{endif}
    size: "${persistence_size}"

  resources:
    requests:
      memory: "${memory_request}"
      cpu: "${cpu_request}"
    limits:
      memory: "${memory_limit}"
      cpu: "${cpu_limit}"

  service:
    type: ${service_type}
    port: ${service_port}
    annotations: {}

%{if architecture == "replication"}
replica:
  replicaCount: ${replicas}
  persistence:
    enabled: ${persistence_enabled}
%{if persistence_enabled && storage_class != ""}
    storageClass: "${storage_class}"
%{endif}
    size: "${persistence_size}"

  resources:
    requests:
      memory: "${memory_request}"
      cpu: "${cpu_request}"
    limits:
      memory: "${memory_limit}"
      cpu: "${cpu_limit}"

  service:
    type: ClusterIP
    port: ${service_port}
%{endif}

%{if sentinel_enabled}
sentinel:
  enabled: true
  quorum: ${sentinel_quorum}

  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
%{endif}

metrics:
  enabled: ${enable_metrics}
  serviceMonitor:
    enabled: false
    additionalLabels: {}
  prometheusRule:
    enabled: false

# Set the following to true to use a custom Redis configuration file
# useExternalConfig: false

# Redis configuration to be loaded during initial boot
# customConfig: |-
#   maxmemory 300mb
#   maxmemory-policy allkeys-lru
#   save 60 1000

# TLS configuration
tls:
  enabled: false
  # cert-manager configuration to automatically issue and renew TLS certificates
  certManager:
    enabled: false
    # issuerRef:
    #   name: "letsencrypt-prod"
    #   kind: "ClusterIssuer"

# Security context configuration
securityContext:
  enabled: true
  fsGroup: 1001
  runAsUser: 1001

# Set common tolerations and node affinity
# tolerations: []
# nodeSelector: {}
# affinity: {}
