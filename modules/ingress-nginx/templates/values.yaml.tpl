controller:
  enableCustomResources: ${enable_custom_resources}
  enableSnippets: ${enable_snippets}
%{if default_tls_secret != ""}
  defaultTLS:
    secret: "${default_tls_secret}"
%{endif}