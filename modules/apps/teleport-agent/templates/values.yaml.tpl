roles: "${roles}"
proxyAddr: "${proxy_server}"
enterprise: false
authToken: "${join_token}"
%{if ca_pin != ""}
caPin:
  - "${ca_pin}"
%{endif}
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
%{endfor}
%{endif}

# Labels and annotations
labels:
  cluster: "${kubernetes_cluster_name}"
  component: "teleport-agent"

annotations:
  cluster: "${kubernetes_cluster_name}"