grafana:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      external-dns.alpha.kubernetes.io/hostname: grafana.fullstack.pw
    labels: {}
    hosts:
      - grafana.fullstack.pw
    path: /
    tls:
    - secretName: prometheus-grafana-tls
      hosts:
      - grafana.fullstack.pw
prometheus:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      external-dns.alpha.kubernetes.io/hostname: prometheus.fullstack.pw
    labels: {}
    hosts:
      - prometheus.fullstack.pw
    path: /
    tls:
    - secretName: prometheus-prometheus-tls
      hosts:
      - prometheus.fullstack.pw
