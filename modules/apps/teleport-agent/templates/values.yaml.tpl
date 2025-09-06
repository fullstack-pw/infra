roles: "${roles}"
proxyAddr: "${proxy_server}"
enterprise: false
authToken: "${join_token}"
teleportClusterName: "${cluster_name}"
kubeClusterName: "${kubernetes_cluster_name}"

%{if length(apps) > 0}
apps:
%{for key, value in apps}
  - name: ${key}
    uri: ${value}
%{endfor}
%{endif}

# Database service configuration
%{if length(databases) > 0}
db_service:
  enabled: true
  resources:
  - labels:
      "*": "*"
databases:
%{for key, value in databases}
  - name: ${key}
    uri: ${value}
    protocol: postgres
    tls:
      ca_cert_file: "/etc/teleport-tls-db/db-ca/ca.pem"
    admin_user:
      name: admin
extraVolumes:
  - name: db-ca
    secret:
      secretName: cluster-secrets
      items:
        - key: POSTGRES_SSL_CA
          path: ca.pem
          mode: 0600
extraVolumeMounts:
  - name: db-ca
    mountPath: /etc/teleport-tls-db/db-ca
    readOnly: true
%{endfor}
%{endif}

# Labels and annotations
labels:
  cluster: "${kubernetes_cluster_name}"
  component: "teleport-agent"

annotations:
  cluster: "${kubernetes_cluster_name}"