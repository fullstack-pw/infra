# Teleport Kubernetes Agent Configuration

# Basic configuration
auth_token: "${join_token}"
proxy_addr: "${proxy_server}"
ca_pin: "${ca_pin}"

# Kubernetes cluster configuration
kubeClusterName: "${kubernetes_cluster_name}"

# Agent configuration
agent:
  log:
    level: "${log_level}"
    output: stderr
    format: json

  # Resource configuration
  resources:
    requests:
      cpu: "${resources.requests.cpu}"
      memory: "${resources.requests.memory}"
    limits:
      cpu: "${resources.limits.cpu}"
      memory: "${resources.limits.memory}"

  # Node selection
  nodeSelector:
%{for key, value in node_selector}
    ${key}: "${value}"
%{endfor}

  # Tolerations
  tolerations:
%{for toleration in tolerations}
    - key: "${toleration.key}"
      operator: "${toleration.operator}"
      value: "${toleration.value}"
      effect: "${toleration.effect}"
%{endfor}

# Service account
serviceAccount:
  create: true
  name: "${cluster_name}-agent"

# Pod security context
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 9807
  runAsGroup: 9807
  fsGroup: 9807

# Security context
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

%{if enable_metrics}
# Monitoring
prometheus:
  enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      app: teleport-agent
      cluster: "${kubernetes_cluster_name}"
%{endif}

# High availability
replicaCount: 1

# Labels and annotations
labels:
  cluster: "${kubernetes_cluster_name}"
  component: "teleport-agent"

annotations:
  cluster: "${kubernetes_cluster_name}"