grafana:
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${grafana_domain}
    labels: {}
    hosts:
      - ${grafana_domain}
    path: /
    tls:
    - secretName: prometheus-grafana-tls
      hosts:
      - ${grafana_domain}
  additionalDataSources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-operated:9090
      access: proxy

prometheus:
  prometheusSpec:
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelectorNilUsesHelmValues: false
    additionalArgs:
      - name: web.enable-otlp-receiver
        value: ""
    enableRemoteWriteReceiver: true
    remoteWriteDashboards: true
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${prometheus_domain}
    labels: {}
    hosts:
      - ${prometheus_domain}
    path: /
    tls:
    - secretName: prometheus-prometheus-tls
      hosts:
      - ${prometheus_domain}