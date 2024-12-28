
resource "helm_release" "minio" {
  name       = "minio"
  namespace  = "default"
  chart      = "minio"
  repository = "https://charts.min.io/"
  #version    = "14.7.0"
  timeout = 120

  values = [
    <<-EOF
rootUser: rootuser
rootPassword: rootpass123
mode: standalone
persistence:
  storageClass: "local-path"
  size: 10Gi
resources:
  requests:
    memory: 512Mi
ingress:
  enabled: true
  annotations:
    external-dns.alpha.kubernetes.io/hostname: s3.fullstack.pw
    cert-manager.io/cluster-issuer: letsencrypt-prod
  ingressClassName: nginx
  hosts:
   - s3.fullstack.pw
  tls:
   - secretName: minio-tls
     hosts:
       - s3.fullstack.pw
consoleIngress:
  enabled: true
  annotations:
    external-dns.alpha.kubernetes.io/hostname: minio.fullstack.pw
    cert-manager.io/cluster-issuer: letsencrypt-prod
  ingressClassName: nginx
  hosts:
   - minio.fullstack.pw
  tls:
   - secretName: minio-console-tls
     hosts:
       - minio.fullstack.pw
EOF
  ] 
}
