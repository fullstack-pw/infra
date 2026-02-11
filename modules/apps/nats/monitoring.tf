/**
 * Monitoring configuration for NATS
 *
 * This file adds monitoring resources when metrics are enabled.
 */

module "monitoring" {
  source = "../../base/monitoring"
  count  = var.prometheus_enabled ? 1 : 0

  name      = "${var.release_name}-nats"
  namespace = module.namespace.name

  # Configure ServiceMonitor for NATS metrics
  create_service_monitor = true
  selector_labels = {
    "app.kubernetes.io/name"     = "nats"
    "app.kubernetes.io/instance" = var.release_name
  }

  endpoints = [
    {
      port          = "metrics"
      path          = "/metrics"
      interval      = "15s"
      scrapeTimeout = "10s"
    }
  ]

  # Add basic NATS alert rules
  create_prometheus_rule = true
  rule_groups = [
    {
      name = "nats.rules"
      rules = [
        {
          alert = "NATSServerDown"
          expr  = "nats_up == 0"
          for   = "1m"
          labels = {
            severity = "critical"
          }
          annotations = {
            summary     = "NATS server is down"
            description = "NATS server {{ $labels.instance }} is down"
          }
        },
        {
          alert = "NATSHighConnections"
          expr  = "nats_connections > 1000"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "NATS has high number of connections"
            description = "NATS server {{ $labels.instance }} has {{ $value }} connections"
          }
        },
        {
          alert = "NATSSlowConsumer"
          expr  = "nats_slow_consumers > 0"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "NATS has slow consumers"
            description = "NATS server {{ $labels.instance }} has {{ $value }} slow consumers"
          }
        },
        {
          alert = "NATSJetStreamHighMemoryUsage"
          expr  = "nats_jetstream_memory_used_bytes / nats_jetstream_memory_total_bytes * 100 > 85"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "NATS JetStream high memory usage (> 85%)"
            description = "NATS JetStream on {{ $labels.instance }} is using {{ $value }}% of allocated memory"
          }
        }
      ]
    }
  ]
}
