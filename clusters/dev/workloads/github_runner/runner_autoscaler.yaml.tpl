apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: github-runner-autoscaler
  namespace: actions-runner-system
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: github-runner
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: PercentageRunnersBusy
    scaleUpThreshold: '0.75'
    scaleDownThreshold: '0.3'
    scaleUpFactor: '1.4'
    scaleDownFactor: '0.7'