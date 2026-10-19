# Alarms -> SNS -> email (or Slack/Chatbot later). One dashboard for the whole platform.

resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  alarm_actions = [aws_sns_topic.alerts.arn]
  services = {
    api    = module.service_api.service_name
    worker = module.service_worker.service_name
  }
}

# ---------- Load balancer ----------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "API is returning server errors"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "api_latency_p95" {
  alarm_name          = "${local.name}-api-latency-p95"
  alarm_description   = "95% of API requests are slower than 1 second"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "api_unhealthy_hosts" {
  alarm_name          = "${local.name}-api-unhealthy-hosts"
  alarm_description   = "At least one API task is failing health checks"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix, TargetGroup = module.service_api.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- ECS services ----------
resource "aws_cloudwatch_metric_alarm" "service_cpu" {
  for_each            = local.services
  alarm_name          = "${local.name}-${each.key}-cpu-high"
  alarm_description   = "${each.key} CPU above 85% (autoscaling may be maxed out)"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = aws_ecs_cluster.this.name, ServiceName = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "service_memory" {
  for_each            = local.services
  alarm_name          = "${local.name}-${each.key}-memory-high"
  alarm_description   = "${each.key} memory above 85%, risk of OOM kills"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = { ClusterName = aws_ecs_cluster.this.name, ServiceName = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Queue ----------
resource "aws_cloudwatch_metric_alarm" "jobs_dlq_not_empty" {
  alarm_name          = "${local.name}-jobs-dlq-not-empty"
  alarm_description   = "Jobs failed 5 times and landed in the dead-letter queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.jobs_dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "jobs_backlog_age" {
  alarm_name          = "${local.name}-jobs-backlog-age"
  alarm_description   = "Oldest job has waited over 5 minutes, worker is falling behind or down"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = aws_sqs_queue.jobs.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------- Dashboard ----------
resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "API requests and errors"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.this.arn_suffix],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "API latency (p50 / p95 / p99, seconds)"
          region = var.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "p50" }],
            ["...", { stat = "p95" }],
            ["...", { stat = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "Service CPU %"
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [for k, svc in local.services : ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", svc, { label = k }]]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "Service memory %"
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = [for k, svc in local.services : ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", svc, { label = k }]]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "Jobs queue"
          region = var.region
          period = 60
          metrics = [
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.jobs.name, { stat = "Sum", label = "sent" }],
            [".", "NumberOfMessagesDeleted", ".", ".", { stat = "Sum", label = "processed" }],
            [".", "ApproximateNumberOfMessagesVisible", ".", ".", { stat = "Maximum", label = "waiting" }],
            [".", "ApproximateNumberOfMessagesVisible", ".", aws_sqs_queue.jobs_dlq.name, { stat = "Maximum", label = "dead-letter" }],
          ]
        }
      },
      {
        type = "alarm", x = 12, y = 12, width = 12, height = 6
        properties = {
          title = "Alarms"
          alarms = concat(
            [
              aws_cloudwatch_metric_alarm.alb_5xx.arn,
              aws_cloudwatch_metric_alarm.api_latency_p95.arn,
              aws_cloudwatch_metric_alarm.api_unhealthy_hosts.arn,
              aws_cloudwatch_metric_alarm.jobs_dlq_not_empty.arn,
              aws_cloudwatch_metric_alarm.jobs_backlog_age.arn,
            ],
            [for a in aws_cloudwatch_metric_alarm.service_cpu : a.arn],
            [for a in aws_cloudwatch_metric_alarm.service_memory : a.arn],
          )
        }
      },
    ]
  })
}
