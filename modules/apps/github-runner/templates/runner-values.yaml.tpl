githubConfigUrl: https://github.com/${github_owner}
githubConfigSecret: cluster-secrets
runnerGroup: "default"
runnerScaleSetName: "self-hosted"
minRunners: ${min_runners}
maxRunners: ${max_runners}

template:
  spec:
    initContainers:
    - name: init-dind-externals
      image: ghcr.io/actions/actions-runner:latest
      command: ["cp", "-r", "/home/runner/externals/.", "/home/runner/tmpDir/"]
      volumeMounts:
        - name: dind-externals
          mountPath: /home/runner/tmpDir
    containers:
      - name: runner
        image: ${runner_image}
        command: ["/home/runner/run.sh"]
%{if working_directory != ""}
        workingDir: ${working_directory}
%{endif}
        volumeMounts:
          - name: kubeconfig-volume
            mountPath: "/home/runner/.kube/config"
            subPath: "kubeconfig"
          - name: sops-volume
            mountPath: "/home/runner/.sops/keys/sops-key.txt"
            subPath: "SOPS"
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /var/run
        env:
          - name: DOCKER_HOST
            value: unix:///var/run/docker.sock
        envFrom:
          - secretRef:
              name: cluster-secrets
              optional: true
        resources:
          limits:
            cpu: "2.0"
            memory: "2Gi"
          requests:
            cpu: "500m"
            memory: "512Mi"
      - name: dind
        image: docker:dind
        args:
          - dockerd
          - --host=unix:///var/run/docker.sock
          - --group=$(DOCKER_GROUP_GID)
        env:
          - name: DOCKER_GROUP_GID
            value: "123"
        securityContext:
          privileged: true
        volumeMounts:
          - name: work
            mountPath: /home/runner/_work
          - name: dind-sock
            mountPath: /var/run
          - name: dind-externals
            mountPath: /home/runner/externals

    volumes:
      - name: kubeconfig-volume
        secret:
          secretName: cluster-secrets
          optional: true
          items:
            - key: KUBECONFIG
              path: kubeconfig
      - name: sops-volume
        secret:
          secretName: cluster-secrets
          optional: true
          items:
            - key: SOPS
              path: SOPS
      - name: work
        emptyDir: {}
      - name: dind-sock
        emptyDir: {}
      - name: dind-externals
        emptyDir: {}
%{if runner_labels != ""}
# Runner labels
runnerLabels:
%{for label in split(",", runner_labels)}
  - ${trim(label)}
%{endfor}
%{endif}
