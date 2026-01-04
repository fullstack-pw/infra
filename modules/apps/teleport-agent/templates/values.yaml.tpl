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

%{if length(databases) > 0}
databases:
%{for name, db in databases}
  - name: ${name}
    uri: ${db.uri}
    protocol: postgres
%{if db.ca_cert != ""}
    tls:
      ca_cert_file: "/etc/teleport-tls-db/${name}/ca.pem"
%{endif}
%{endfor}
%{endif}

%{if length([for name, db in databases : name if db.ca_cert != ""]) > 0}
extraVolumes:
%{for name, db in databases}
%{if db.ca_cert != ""}
  - name: ${name}-ca
    secret:
      secretName: ${name}-ca
%{endif}
%{endfor}

extraVolumeMounts:
%{for name, db in databases}
%{if db.ca_cert != ""}
  - name: ${name}-ca
    mountPath: /etc/teleport-tls-db/${name}
    readOnly: true
%{endif}
%{endfor}
%{endif}

labels:
  cluster: "${kubernetes_cluster_name}"
  component: "teleport-agent"

annotations:
  cluster: "${kubernetes_cluster_name}"
