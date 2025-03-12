server:
  dataStorage:
    enabled: ${data_storage_enabled}
%{if data_storage_storage_class != ""}
    storageClass: ${data_storage_storage_class}
%{endif}
  ingress:
    enabled: ${ingress_enabled}
%{if ingress_class_name != ""}
    ingressClassName: "${ingress_class_name}"
%{endif}
%{if length(ingress_annotations) > 0}
    annotations:
%{for key, value in ingress_annotations}
      ${key}: "${value}"
%{endfor}
%{endif}
%{if ingress_host != ""}
    hosts:
      - host: ${ingress_host}
%{endif}
%{if tls_secret_name != ""}
    tls:
    - secretName: ${tls_secret_name}
      hosts:
        - ${ingress_host}
%{endif}
ui:
  enabled: ${ui_enabled}