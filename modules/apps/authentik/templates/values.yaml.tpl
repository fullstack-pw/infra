authentik:
  secret_key: "${secret_key}"
  error_reporting:
    enabled: false
  postgresql:
    host: "${pg_host}"
    port: ${pg_port}
    name: "${pg_name}"
    user: "${pg_user}"
  redis:
    host: "${redis_host}"
    port: ${redis_port}
    password: "${redis_password}"
    db: ${redis_db}

global:
  env:
    - name: AUTHENTIK_POSTGRESQL__PASSWORD
      valueFrom:
        secretKeyRef:
          name: ${pg_secret_name}
          key: password
    - name: AUTHENTIK_BOOTSTRAP_PASSWORD
      value: "${admin_password}"
    - name: AUTHENTIK_BOOTSTRAP_EMAIL
      value: "${admin_email}"

server:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      external-dns.alpha.kubernetes.io/hostname: ${domain}
    hosts:
      - ${domain}
    tls:
      - secretName: authentik-tls
        hosts:
          - ${domain}

worker:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

postgresql:
  enabled: false

redis:
  enabled: false
