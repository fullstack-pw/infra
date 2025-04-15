grafana:
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${grafana_domain}
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
    additionalArgs:
      - name: web.enable-otlp-receiver
        value: ""
    enableRemoteWriteReceiver: true
    remoteWriteDashboards: true
    scrapeClasses:
      - default: true
        name: cluster-relabeling
        relabelings:
          - sourceLabels: [ __name__ ]
            regex: (.*)
            targetLabel: cluster
            replacement: ${cluster_name}
            action: replace
  ingress:
    enabled: true
    ingressClassName: ${ingress_class_name}
    annotations:
      cert-manager.io/cluster-issuer: ${cert_manager_cluster_issuer}
      external-dns.alpha.kubernetes.io/hostname: ${prometheus_domain}
    hosts:
      - ${prometheus_domain}
    path: /
    tls:
    - secretName: prometheus-prometheus-tls
      hosts:
      - ${prometheus_domain}
