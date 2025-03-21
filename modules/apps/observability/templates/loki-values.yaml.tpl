deploymentMode: ${deployment_mode}
minio:
  enabled: true
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  pattern_ingester:
      enabled: true
  ruler:
    enable_api: true
  storage:
    type: ${storage_type}
    ${storage_type}:
      store: filesystem
      ${filesystem_directory_key}: /data/loki
  limits_config:
    retention_period: ${retention_period}
    allow_structured_metadata: true
    volume_enabled: true

limits_config:
  allow_structured_metadata: true

singleBinary:
  replicas: ${replicas}
  resources:
    requests:
      memory: "${memory_request}"
      cpu: "${cpu_request}"
    limits:
      memory: "${memory_limit}"
      cpu: "${cpu_limit}"
  persistence:
    enabled: ${persistence_enabled}
    size: ${persistence_size}
%{if persistence_storage_class != ""}
    storageClass: ${persistence_storage_class}
%{endif}

chunksCache:
  allocatedMemory: 1024

ingress:
  enabled: true
  ingressClassName: ${ingress_class_name}
  annotations:
    cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
    external-dns.alpha.kubernetes.io/hostname: ${loki_domain}
    nginx.ingress.kubernetes.io/proxy-body-size: 16m
  hosts:
    - ${loki_domain}
  tls:
    - secretName: loki-tls
      hosts:
        - ${loki_domain}
gateway:
  enabled: false
grafana:
  enabled: false
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
ingester:
  replicas: 0
querier:
  replicas: 0
queryFrontend:
  replicas: 0
queryScheduler:
  replicas: 0
distributor:
  replicas: 0
compactor:
  replicas: 0
indexGateway:
  replicas: 0
bloomCompactor:
  replicas: 0
bloomGateway:
  replicas: 0