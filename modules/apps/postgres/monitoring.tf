/**
 * Monitoring configuration for PostgreSQL
 * 
 * This file adds monitoring resources when metrics are enabled.
 */

module "monitoring" {
  source = "../../base/monitoring"
  count  = var.enable_metrics ? 1 : 0

  name      = "${var.release_name}-postgresql"
  namespace = module.namespace.name

  # Configure ServiceMonitor for PostgreSQL metrics
  create_service_monitor = true
  selector_labels = {
    "app.kubernetes.io/name"     = "postgresql"
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

  # Add PostgreSQL alert rules
  create_prometheus_rule = true
  rule_groups = [
    {
      name = "postgresql.rules"
      rules = [
        {
          alert = "PostgreSQLDown"
          expr  = "pg_up == 0"
          for   = "1m"
          labels = {
            severity = "critical"
          }
          annotations = {
            summary     = "PostgreSQL instance is down"
            description = "PostgreSQL instance {{ $labels.instance }} is down"
          }
        },
        {
          alert = "PostgreSQLHighConnections"
          expr  = "sum by (instance) (pg_stat_activity_count) > (pg_settings_max_connections * 0.8)"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "PostgreSQL approaching connection limit (> 80%)"
            description = "PostgreSQL instance {{ $labels.instance }} is using {{ $value }}% of available connections."
          }
        },
        {
          alert = "PostgreSQLReplicationLag"
          expr  = "pg_replication_lag > 30"
          for   = "5m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "PostgreSQL replication lag is high"
            description = "PostgreSQL replication for instance {{ $labels.instance }} lag is {{ $value }} seconds."
          }
        },
        {
          alert = "PostgreSQLHighDiskUsage"
          expr  = "pg_database_size_bytes / pg_database_size_bytes_total > 0.85"
          for   = "10m"
          labels = {
            severity = "warning"
          }
          annotations = {
            summary     = "PostgreSQL database disk usage is high (> 85%)"
            description = "PostgreSQL database {{ $labels.datname }} on instance {{ $labels.instance }} is using {{ $value }}% of available disk space."
          }
        }
      ]
    }
  ]
}
