## PostgreSQL values for Helm chart
image:
  tag: ${pg_version}

auth:
  username: "${postgres_username}"
  password: "${postgres_password}"
  database: "${postgres_database}"
  existingSecret: ""

primary:
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

%{if replication_enabled}
architecture: replication

replication:
  enabled: true
  replicas: ${replication_replicas}
  synchronousCommit: "on"
  numSynchronousReplicas: ${ha_enabled ? replication_replicas - 1 : 0}
%{else}
architecture: standalone
%{endif}

service:
  type: ${service_type}
  port: ${service_port}

metrics:
  enabled: ${enable_metrics}
  serviceMonitor:
    enabled: ${enable_metrics}

%{if ingress_enabled}
ingress:
  enabled: ${ingress_enabled}
%{if ingress_class_name != ""}
  ingressClassName: "${ingress_class_name}"
%{endif}
  hostname: "${ingress_host}"
%{if ingress_tls_enabled}
  tls: true
  selfSigned: false
  secrets:
    - name: "${ingress_tls_secret}"
%{endif}
%{endif}