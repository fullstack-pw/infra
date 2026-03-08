replicaCount: ${replicas}

gitea:
  instanceURL: ${gitea_url}
  runnerToken: "${runner_token}"

config:
  runner:
    name: ${runner_name}
    labels:
%{for label in split(",", runner_labels)}
      - "${trimspace(label)}"
%{endfor}
    log_level: info
  container:
    network: bridge
    privileged: false
