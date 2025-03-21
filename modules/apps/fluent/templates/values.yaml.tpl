config:
  outputs: |
    [OUTPUT]
        host loki.fullstack.pw
        name                   loki
        match                  *
        labels                 job=fluentbit,cluster=${CLUSTER}
        auto_kubernetes_labels on
        port 443
        tls on