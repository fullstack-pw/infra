githubConfigUrl: https://github.com/${github_owner}
githubConfigSecret: cluster-secrets
runnerGroup: "default"
runnerScaleSetName: "self-hosted"
minRunners: ${min_runners}
maxRunners: ${max_runners}

template:
  spec:
    containers:
      - name: runner
        image: ${runner_image}
        command: ["/home/runner/run.sh"]
%{if working_directory != ""}
        workingDir: ${working_directory}
%{endif}
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
        volumeMounts:
          - name: kubeconfig-volume
            mountPath: "/home/runner/.kube/config"
            subPath: "kubeconfig"
          - name: sops-volume
            mountPath: "/home/runner/.sops/keys/sops-key.txt"
            subPath: "SOPS"
          - name: work
            mountPath: /home/runner/_work
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
%{if runner_labels != ""}
# Runner labels
runnerLabels:
%{for label in split(",", runner_labels)}
  - ${trim(label)}
%{endfor}
%{endif}
