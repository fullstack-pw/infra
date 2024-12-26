apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: github-runner
  namespace: actions-runner-system
spec:
  template:
    spec:
      organization: ${github_owner}
      serviceAccountName: github-runner
      containers:
        - name: runner
          env:
            - name: KUBECONFIG
              value: "/etc/kubeconfig"
          volumeMounts:
            - name: kubeconfig-volume
              mountPath: "/etc/kubeconfig"
              subPath: KUBECONFIG
      volumes:
        - name: kubeconfig-volume
          secret:
            secretName: kubeconfig
