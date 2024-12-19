apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: github-runner
  namespace: actions-runner-system
spec:
  replicas: ${runner_replicas}
  template:
    spec:
      organization: ${github_owner}
