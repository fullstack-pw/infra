apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: ${namespace}
spec:
  certificateRotateStrategy: {}
  configuration:
%{ if length(feature_gates) > 0 ~}
    developerConfiguration:
      featureGates:
%{ for gate in feature_gates ~}
        - ${gate}
%{ endfor ~}
%{ endif ~}
  customizeComponents: {}
  imagePullPolicy: IfNotPresent
  workloadUpdateStrategy: {}
