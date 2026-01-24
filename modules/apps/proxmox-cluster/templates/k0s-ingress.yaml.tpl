apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${cluster_name}-apiserver
  namespace: ${namespace}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.passthrough: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  rules:
  - host: ${control_plane_endpoint_host}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${k0smotron_control_plane_name}
            port:
              number: 6443
  tls:
  - hosts:
    - ${control_plane_endpoint_host}
    secretName: ${cluster_name}-api-tls
