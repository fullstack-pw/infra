apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: ${autoscaler_name}
  namespace: ${namespace}
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: ${runner_deployment_name}
  minReplicas: ${min_replicas}
  maxReplicas: ${max_replicas}
  metrics:
    - type: PercentageRunnersBusy
      scaleUpThreshold: ${scale_up_threshold}
      scaleDownThreshold: ${scale_down_threshold}
      scaleUpFactor: ${scale_up_factor}
      scaleDownFactor: ${scale_down_factor}