env:
  REDIS_HOSTNAME: ${redis}
  REDIS_PASSWORD: ${redis_pass}
  DB_HOSTNAME: ${db_hostname}
  DB_USERNAME: ${db_user}
  DB_DATABASE_NAME: ${db_name}
  DB_PASSWORD: ${db_pass}
  IMMICH_MACHINE_LEARNING_URL: "http://immich-ml.immich.svc.cluster.local:3003"

image:
  tag: v1.119.0

immich:
  persistence:
    library:
      existingClaim: immich-data
  configuration: {}

server:
  enabled: true
  image:
    repository: ghcr.io/immich-app/immich-server
    pullPolicy: IfNotPresent
  ingress:
    main:
      enabled: true
      annotations:
%{for key, value in ingress_annotations}
        ${key}: "${value}"
%{endfor}
      hosts:
        - host: ${immich_domain}
          paths:
            - path: "/"
      tls:
        - secretName: "${ingress_tls_secret_name}"
          hosts:
            - "${immich_domain}"

machine-learning:
  persistence:
    cache:
      enabled: true
      size: 20Gi
      type: emptyDir
      accessMode: ReadWriteMany
      storageClass: local-path
