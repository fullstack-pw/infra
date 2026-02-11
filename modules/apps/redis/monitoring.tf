/**
 * Monitoring configuration for Redis
 *
 * This file adds monitoring resources when metrics are enabled.
 */

module "monitoring" {
  source = "../../base/monitoring"
  count  = var.enable_metrics ? 1 : 0

  name      = "${var.release_name}-redis"
  namespace = module.namespace.name

  # Configure ServiceMonitor for Redis metrics
  create_service_monitor = true
  selector_labels = {
    "app.kubernetes.io/name"     = "redis"
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

  # Add basic Redis alert rules
  create_prometheus_rule = true
  rule_groups = [
    {
      name = "redis.rules"
      rules = [
        {
          alert = "RedisDown"
          expr  = "redis_up == 0"
          for   = "1m"
          labels = {
            severity = "critical"
          }
          annotations = {
            summary     = "Redis instance is down"
            description = "Redis instance {{ $labels.instance }} is down"
          }
        },
        {
          alert = "RedisOutOfMemory"
          expr  = "redis_memory_used_bytes / redis_memory_max_bytes * 100 > 90"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "Redis is running out of memory (> 90%)"
            description = "Redis instance {{ $labels.instance }} is using {{ $value }}% of its available memory."
          }
        },
        {
          alert = "RedisTooManyConnections"
          expr  = "redis_connected_clients > 100"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "Redis has too many connections"
            description = "Redis instance {{ $labels.instance }} has {{ $value }} connections."
          }
        }
      ]
    }
  ]
}
