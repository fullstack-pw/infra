global:
  domain: ${domain}

configs:
  params:
    server.insecure: true
    application.namespaces: "${application_namespaces}"

  cm:
    url: https://${domain}
    statusbadge.enabled: "true"
    exec.enabled: "true"

  rbac:
    policy.default: role:readonly

  secret:
    argocdServerAdminPassword: ${admin_password_bcrypt}

server:
  ingress:
    enabled: false

  resources:
    requests:
      cpu: ${server_cpu_request}
      memory: ${server_memory_request}
    limits:
      cpu: ${server_cpu_limit}
      memory: ${server_memory_limit}

repoServer:
  resources:
    requests:
      cpu: ${repo_cpu_request}
      memory: ${repo_memory_request}
    limits:
      cpu: ${repo_cpu_limit}
      memory: ${repo_memory_limit}

controller:
  resources:
    requests:
      cpu: ${controller_cpu_request}
      memory: ${controller_memory_request}
    limits:
      cpu: ${controller_cpu_limit}
      memory: ${controller_memory_limit}

redis:
  enabled: true

dex:
  enabled: ${enable_dex}

notifications:
  enabled: ${enable_notifications}
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

applicationSet:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
