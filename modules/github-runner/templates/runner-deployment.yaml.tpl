apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: ${runner_name}
  namespace: ${namespace}
spec:
  replicas: ${replicas}
  template:
    spec:
      organization: ${organization}
      serviceAccountName: ${service_account_name}
      # Use environment variables from the secrets
      envFrom:
        - secretRef:
            name: cluster-secrets
      containers:
        - name: runner
%{if runner_labels != ""}
          labels:
            - ${runner_labels}
%{endif}
%{if image != ""}
          image: ${image}
%{endif}
%{if working_directory != ""}
          workingDir: ${working_directory}
%{endif}