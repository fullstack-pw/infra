apiVersion: externaldns.k8s.io/v1alpha1
kind: DNSEndpoint
metadata:
  name: ${CLUSTER_NAME}-dns
  namespace: default
  labels:
    ephemeral: "true"
    cluster: "${CLUSTER_NAME}"
spec:
  endpoints:
    - dnsName: ${DNS_NAME}
      recordTTL: 300
      recordType: A
      targets:
        - ${CLUSTER_IP}
