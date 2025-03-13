controller:
  config:
    use-forwarded-headers: "true"
    enable-grpc: "true"
    http2: "true"
    http2-max-field-size: "16384"
    http2-max-header-size: "16384"
    http2-max-requests-per-connection: "1000"
    grpc-buffer-size: "4k"
    upstream-keepalive-timeout: "300"
    proxy-stream-timeout: "3600s"
    proxy-stream-next-upstream-timeout: "3600s"
  enableCustomResources: ${enable_custom_resources}
  enableSnippets: ${enable_snippets}
  service:
    externalTrafficPolicy: "Local"
  publishService:
    enabled: true
%{if default_tls_secret != ""}
  defaultTLS:
    secret: "${default_tls_secret}"
%{endif}