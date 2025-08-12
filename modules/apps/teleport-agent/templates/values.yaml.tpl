roles: "${roles}"
proxyAddr: "${proxy_server}"
enterprise: false
authToken: "${join_token}"
teleportClusterName: "${cluster_name}"
kubeClusterName: "${kubernetes_cluster_name}"

%{if apps != ""}
apps:
%{for key, value in apps}
  - name: ${key}
    uri: ${value}
%{endfor}
%{endif}

# Labels and annotations
labels:
  cluster: "${kubernetes_cluster_name}"
  component: "teleport-agent"

annotations:
  cluster: "${kubernetes_cluster_name}"