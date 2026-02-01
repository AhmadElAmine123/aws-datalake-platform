variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications"
}

variable "batch_ingest_function_name" {
  type = string
}

variable "stream_generate_function_name" {
  type = string
}

variable "glue_job_name" {
  type = string
}

# ─── SNS Topic ───────────────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts-${var.environment}"
  display_name      = "DataLake Alerts (${var.environment})"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─── Lambda Error Alarms ─────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "batch_ingest_errors" {
  alarm_name          = "${var.project_name}-batch-ingest-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Batch ingest Lambda had errors in the last 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.batch_ingest_function_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "stream_generate_errors" {
  alarm_name          = "${var.project_name}-stream-generate-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Stream generate Lambda had errors in the last 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.stream_generate_function_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Lambda Duration Alarm (batch ingest taking too long) ───────────────────
resource "aws_cloudwatch_metric_alarm" "batch_ingest_duration" {
  alarm_name          = "${var.project_name}-batch-ingest-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90000"  # 90 seconds in ms
  alarm_description   = "Batch ingest Lambda took more than 90 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.batch_ingest_function_name
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Glue Job Failure Alarm ──────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "glue_job_failures" {
  alarm_name          = "${var.project_name}-glue-transform-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.job.status"
  namespace           = "AWS/Glue"
  period              = "3600"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Glue transform job failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  # Glue metrics use job name dimension
  dimensions = {
    JobName = var.glue_job_name
  }

  # Treat missing data as OK (job may not have run yet)
  treat_missing_data = "ok"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Firehose Delivery Alarm ─────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "firehose_delivery_errors" {
  alarm_name          = "${var.project_name}-firehose-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DeliveryToS3.Success"
  namespace           = "AWS/Firehose"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Kinesis Firehose S3 delivery success rate is 0"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "ok"

  dimensions = {
    DeliveryStream = "${var.project_name}-iot-firehose-${var.environment}"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
