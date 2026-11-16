##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-sns-alarms.
locals {
  name_prefix = var.environment

  # Redis node 001 is the primary of a single-node group.
  redis_node_id = "${var.redis_replication_group_id}-001"

  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tg_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  ecs_dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  rds_dimensions   = { DBInstanceIdentifier = var.db_instance_identifier }
  redis_dimensions = { CacheClusterId = local.redis_node_id }

  # One entry per alarm; the resource below turns each into a CloudWatch alarm.
  alarms = {
    alb-5xx = {
      description = "Application returns server errors"
      namespace   = "AWS/ApplicationELB"
      metric      = "HTTPCode_Target_5XX_Count"
      statistic   = "Sum"
      comparison  = "GreaterThanThreshold"
      threshold   = var.alb_5xx_threshold
      dimensions  = local.alb_dimensions
      missing     = "notBreaching"
    }
    alb-unhealthy-hosts = {
      description = "A target is failing its health check"
      namespace   = "AWS/ApplicationELB"
      metric      = "UnHealthyHostCount"
      statistic   = "Maximum"
      comparison  = "GreaterThanOrEqualToThreshold"
      threshold   = 1
      dimensions  = local.tg_dimensions
      missing     = "notBreaching"
    }
    alb-healthy-hosts-low = {
      description = "Fewer healthy targets than the minimum (one per zone)"
      namespace   = "AWS/ApplicationELB"
      metric      = "HealthyHostCount"
      statistic   = "Minimum"
      comparison  = "LessThanThreshold"
      threshold   = var.min_healthy_hosts
      dimensions  = local.tg_dimensions
      missing     = "breaching"
    }
    alb-response-time = {
      description = "Slow responses from the application"
      namespace   = "AWS/ApplicationELB"
      metric      = "TargetResponseTime"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.response_time_threshold_seconds
      dimensions  = local.alb_dimensions
      missing     = "notBreaching"
    }
    app-errors = {
      description = "Application logs ERROR lines"
      namespace   = "${local.name_prefix}/app"
      metric      = "ErrorCount"
      statistic   = "Sum"
      comparison  = "GreaterThanThreshold"
      threshold   = var.app_errors_threshold
      dimensions  = {}
      missing     = "notBreaching"
    }
    ecs-cpu = {
      description = "ECS service CPU is high"
      namespace   = "AWS/ECS"
      metric      = "CPUUtilization"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.cpu_threshold_percent
      dimensions  = local.ecs_dimensions
      missing     = "missing"
    }
    ecs-memory = {
      description = "ECS service memory is high"
      namespace   = "AWS/ECS"
      metric      = "MemoryUtilization"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.memory_threshold_percent
      dimensions  = local.ecs_dimensions
      missing     = "missing"
    }
    rds-cpu = {
      description = "Database CPU is high"
      namespace   = "AWS/RDS"
      metric      = "CPUUtilization"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.cpu_threshold_percent
      dimensions  = local.rds_dimensions
      missing     = "missing"
    }
    rds-free-storage = {
      description = "Database free storage is low"
      namespace   = "AWS/RDS"
      metric      = "FreeStorageSpace"
      statistic   = "Minimum"
      comparison  = "LessThanThreshold"
      threshold   = var.db_free_storage_min_gib * 1024 * 1024 * 1024
      dimensions  = local.rds_dimensions
      missing     = "missing"
    }
    rds-connections = {
      description = "Database connections are high"
      namespace   = "AWS/RDS"
      metric      = "DatabaseConnections"
      statistic   = "Maximum"
      comparison  = "GreaterThanThreshold"
      threshold   = var.db_connections_threshold
      dimensions  = local.rds_dimensions
      missing     = "missing"
    }
    redis-cpu = {
      description = "Redis engine CPU is high"
      namespace   = "AWS/ElastiCache"
      metric      = "EngineCPUUtilization"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.cpu_threshold_percent
      dimensions  = local.redis_dimensions
      missing     = "missing"
    }
    redis-memory = {
      description = "Redis memory is high"
      namespace   = "AWS/ElastiCache"
      metric      = "DatabaseMemoryUsagePercentage"
      statistic   = "Average"
      comparison  = "GreaterThanThreshold"
      threshold   = var.memory_threshold_percent
      dimensions  = local.redis_dimensions
      missing     = "missing"
    }
  }
}
