global:
  storageClass: ${storage_class}

replicaCount: 1

image:
  pullPolicy: IfNotPresent

service:
  http:
    type: ClusterIP
    port: 3000
  ssh:
    type: NodePort
    port: 22
    nodePort: ${ssh_port}

ingress:
  enabled: ${ingress_enabled}
  className: ${ingress_class_name}
  annotations:
%{for key, value in ingress_annotations}
    ${key}: "${value}"
%{endfor}
  hosts:
    - host: ${domain}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: gitea-tls
      hosts:
        - ${domain}

gitea:
  admin:
    username: ${admin_username}
    password: "${admin_password}"
    email: ${admin_email}
  config:
    server:
      DOMAIN: ${domain}
      SSH_DOMAIN: ${ssh_domain}
      ROOT_URL: "https://${domain}"
      SSH_PORT: 22
      SSH_LISTEN_PORT: 2222
    database:
      DB_TYPE: postgres
      HOST: "${external_database_host}:${external_database_port}"
      NAME: ${external_database_name}
      USER: ${external_database_username}
      PASSWD: "${external_database_password}"
      SSL_MODE: ${external_database_ssl_mode}
    cache:
      ADAPTER: redis
      HOST: "redis://:${external_redis_password}@${external_redis_host}:${external_redis_port}/0"
    session:
      PROVIDER: redis
      PROVIDER_CONFIG: "redis://:${external_redis_password}@${external_redis_host}:${external_redis_port}/1"
    queue:
      TYPE: redis
      CONN_STR: "redis://:${external_redis_password}@${external_redis_host}:${external_redis_port}/2"
    security:
      SECRET_KEY: "${secret_key}"
      INTERNAL_TOKEN: "${internal_token}"
    actions:
      ENABLED: true
      DEFAULT_ACTIONS_URL: ${default_actions_url}
    mailer:
      ENABLED: false
    log:
      LEVEL: Info

persistence:
  enabled: true
  storageClass: ${storage_class}
  size: ${storage_size}
  accessModes:
    - ReadWriteOnce

postgresql:
  enabled: false

postgresql-ha:
  enabled: false

redis-cluster:
  enabled: false
