expose:
  type: ingress
  tls:
    enabled: ${tls_enabled}
    certSource: secret
    secret:
      secretName: ${tls_cert_secret_name}
  ingress:
    hosts:
      core: ${harbor_domain}
    className: ${ingress_class_name}
    annotations:
%{for key, value in ingress_annotations}
      ${key}: "${value}"
%{endfor}

externalURL: https://${harbor_domain}

harborAdminPassword: "${admin_password}"

# Persistence configuration
persistence:
  enabled: ${persistence_enabled}
  resourcePolicy: "keep"
%{if persistence_enabled && storage_class != ""}
  persistentVolumeClaim:
    registry:
      storageClass: ${storage_class}
    chartmuseum:
      storageClass: ${storage_class}
    jobservice:
      jobLog:
        storageClass: ${storage_class}
    database:
      storageClass: ${storage_class}
    redis:
      storageClass: ${storage_class}
    trivy:
      storageClass: ${storage_class}
%{endif}

# External database configuration
database:
  type: external
  external:
    host: "${external_database_host}"
    port: ${external_database_port}
    username: "${external_database_username}"
    password: "${external_database_password}"
    sslmode: "${external_database_sslmode}"
    database: "${external_database_database}"

redis:
  type: external
  external:
    addr: "${external_redis_host}:${external_redis_port}"
    password: "${external_redis_password}"
    databaseIndex: ${external_redis_database_index}
core:
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.core.cpu}
      memory: ${resources_limits.core.memory}
    requests:
      cpu: ${resources_requests.core.cpu}
      memory: ${resources_requests.core.memory}

jobservice:
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.jobservice.cpu}
      memory: ${resources_limits.jobservice.memory}
    requests:
      cpu: ${resources_requests.jobservice.cpu}
      memory: ${resources_requests.jobservice.memory}

registry:
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.registry.cpu}
      memory: ${resources_limits.registry.memory}
    requests:
      cpu: ${resources_requests.registry.cpu}
      memory: ${resources_requests.registry.memory}

portal:
  replicas: 1
  resources:
    limits:
      cpu: ${resources_limits.portal.cpu}
      memory: ${resources_limits.portal.memory}
    requests:
      cpu: ${resources_requests.portal.cpu}
      memory: ${resources_requests.portal.memory}
notary:
  enabled: false
chartmuseum:
  enabled: false
trivy:
  enabled: true
  resources:
    limits:
      cpu: ${resources_limits.portal.cpu}
      memory: ${resources_limits.portal.memory}
    requests:
      cpu: ${resources_requests.portal.cpu}
      memory: ${resources_requests.portal.memory}
log:
  level: info
  audit:
    enabled: true