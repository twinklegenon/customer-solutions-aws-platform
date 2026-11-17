##################################
# Environment-Specific Resources
##################################

# --- Notifications: every alarm publishes to one encrypted topic ---------

resource "aws_sns_topic" "alarms" {
  name              = "${local.name_prefix}-sns-alarms"
  kms_master_key_id = var.sns_kms_key_arn
}

# The subscriber must confirm the email once after the first apply.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# --- Alarms (defined in locals.tf) ----------------------------------------

resource "aws_cloudwatch_metric_alarm" "alarm" {
  for_each = local.alarms

  alarm_name          = "${local.name_prefix}-alarm-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  comparison_operator = each.value.comparison
  threshold           = each.value.threshold
  dimensions          = each.value.dimensions
  treat_missing_data  = each.value.missing

  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# --- Application errors: count error lines in the app log (alarm app-errors) ---

resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${local.name_prefix}-app-errors"
  log_group_name = var.app_log_group_name
  pattern        = "?ERROR ?Error ?error"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "${local.name_prefix}/app"
    value         = "1"
    default_value = "0"
  }
}

# --- RDS events: tell the topic when the database fails over -----------------

resource "aws_db_event_subscription" "rds" {
  name             = "${local.name_prefix}-rds-events"
  sns_topic        = aws_sns_topic.alarms.arn
  source_type      = "db-instance"
  source_ids       = [var.db_instance_identifier]
  event_categories = ["failover", "failure"]
}

# --- Dashboard: one row per service ---------------------------------------

resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "${local.name_prefix}-dashboard-platform"

  dashboard_body = jsonencode({
    widgets = concat([
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB requests and errors"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB healthy targets and response time"
          region = var.region
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Minimum" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Maximum" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ECS service CPU and memory (%)"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS CPU (%) and connections"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_identifier, { yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "RDS free storage (bytes)"
          region = var.region
          stat   = "Minimum"
          period = 300
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_identifier],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Redis engine CPU and memory (%)"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", local.redis_node_id],
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", local.redis_node_id],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 18, width = 12, height = 6
        properties = {
          title  = "CloudFront requests and error rate"
          region = "us-east-1"
          period = 300
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Sum" }],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", var.cloudfront_distribution_id, "Region", "Global", { stat = "Average", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 18, width = 12, height = 6
        properties = {
          title  = "WAF allowed and blocked requests"
          region = "us-east-1"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL"],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", var.waf_web_acl_name, "Rule", "ALL"],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 24, width = 12, height = 6
        properties = {
          title  = "Application ERROR log lines"
          region = var.region
          stat   = "Sum"
          period = 300
          metrics = [
            ["${local.name_prefix}/app", "ErrorCount"],
          ]
        }
      },
    ], local.dr_widgets)
  })
}
