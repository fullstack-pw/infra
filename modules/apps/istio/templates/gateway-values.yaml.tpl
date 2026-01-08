# Istio Ingress Gateway Configuration

replicaCount: ${gateway_replicas}

service:
  type: ${service_type}
%{ if service_type == "LoadBalancer" && load_balancer_ip != "" ~}
  loadBalancerIP: ${load_balancer_ip}
%{ endif ~}
%{ if service_type == "NodePort" ~}
  nodePorts:
    http: ${node_port_http}
    https: ${node_port_https}
%{ endif ~}
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8443
  - name: postgresql
    port: 5432
    protocol: TCP
    targetPort: 5432
  - name: postgresql-tcp
    port: 5433
    protocol: TCP
    targetPort: 5433

# Resource requests and limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 2000m
    memory: 1024Mi

# Autoscaling
autoscaling:
  enabled: false
  minReplicas: ${gateway_replicas}
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80

# Pod annotations
podAnnotations:
  prometheus.io/port: "15020"
  prometheus.io/scrape: "true"
  prometheus.io/path: "/stats/prometheus"

# Security context
securityContext:
  runAsUser: 1337
  runAsGroup: 1337
  runAsNonRoot: true
  fsGroup: 1337

# Service account
serviceAccount:
  create: true
  name: istio-ingressgateway
