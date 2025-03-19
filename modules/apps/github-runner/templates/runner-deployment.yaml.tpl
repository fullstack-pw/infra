apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: ${runner_name}
  namespace: ${namespace}
spec:
  replicas: ${replicas}
  template:
    spec:
      volumes:
        - name: kubeconfig-volume
          secret:
            secretName: cluster-secrets
            items:
              - key: KUBECONFIG
                path: kubeconfig
      organization: ${organization}
      serviceAccountName: ${service_account_name}
      envFrom:
        - secretRef:
            name: cluster-secrets
      containers:
        - name: runner
          volumeMounts:
            - name: kubeconfig-volume
              mountPath: /home/runner/.kube/config
              subPath: kubeconfig
%{if runner_labels != ""}
          labels:
            - ${runner_labels}
%{endif}
%{if image != "" && if image != null}
          image: ${image}
%{endif}
%{if working_directory != ""}
          workingDir: ${working_directory}
%{endif}