apiVersion: cdi.kubevirt.io/v1beta1
kind: CDI
metadata:
  name: cdi
  namespace: ${namespace}
spec:
  config:
%{ if length(feature_gates) > 0 ~}
    featureGates:
%{ for gate in feature_gates ~}
    - ${gate}
%{ endfor ~}
%{ endif ~}
    insecureRegistries:
      - "*.svc"
    filesystemOverhead:
      global: "0.055"
      storageClass:
        longhorn: "0.055"
    uploadProxyURLOverride: "https://cdi-uploadproxy.fullstack.pw"
  imagePullPolicy: IfNotPresent
  infra:
    nodeSelector:
      kubernetes.io/os: linux
    tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
  workload:
    nodeSelector:
      kubernetes.io/os: linux
