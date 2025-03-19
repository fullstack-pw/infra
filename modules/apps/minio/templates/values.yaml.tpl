rootUser: "${root_user}"
rootPassword: "${root_password}"
mode: "${mode}"
persistence:
  enabled: ${persistence_enabled}
%{if persistence_storage_class != ""}
  storageClass: "${persistence_storage_class}"
%{endif}
  size: "${persistence_size}"
resources:
  requests:
    memory: "${memory_request}"
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
   - "${ingress_host}"
%{endif}
%{if ingress_tls_enabled}
  tls:
   - secretName: "${ingress_tls_secret_name}"
     hosts:
       - "${ingress_host}"
%{endif}
consoleIngress:
  enabled: ${console_ingress_enabled}
%{if console_ingress_class_name != ""}
  ingressClassName: "${console_ingress_class_name}"
%{endif}
  annotations:
    kubernetes.io/ingress.class: "${console_ingress_class_name}"
    nginx.org/location-snippets: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
%{if length(console_ingress_annotations) > 0}
%{for key, value in console_ingress_annotations}
    ${key}: "${value}"
%{endfor}
%{endif}
%{if console_ingress_host != ""}
  hosts:
   - "${console_ingress_host}"
%{endif}
%{if console_ingress_tls_enabled}
  tls:
   - secretName: "${console_ingress_tls_secret_name}"
     hosts:
       - "${console_ingress_host}"
%{endif}