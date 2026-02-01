variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "batch_ingest_function_arn" {
  type = string
}

variable "stream_generate_function_arn" {
  type = string
}

variable "glue_job_name" {
  type = string
}

variable "batch_schedule" {
  type        = string
  description = "Cron expression for batch ingestion (e.g., rate(1 day))"
  default     = "rate(1 day)"
}

variable "stream_schedule" {
  type        = string
  description = "Rate expression for stream generation (e.g., rate(5 minutes))"
  default     = "rate(5 minutes)"
}

variable "transform_schedule" {
  type        = string
  description = "Rate expression for Glue transform trigger"
  default     = "rate(1 hour)"
}

# ─── Batch Ingest Schedule ───────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "batch_ingest" {
  name                = "${var.project_name}-batch-ingest-${var.environment}"
  description         = "Triggers batch weather data ingestion daily"
  schedule_expression = var.batch_schedule
  state               = "ENABLED"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "batch_ingest" {
  rule      = aws_cloudwatch_event_rule.batch_ingest.name
  target_id = "BatchIngestLambda"
  arn       = var.batch_ingest_function_arn
  role_arn  = aws_iam_role.eventbridge.arn
}

# ─── Stream Generate Schedule ────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "stream_generate" {
  name                = "${var.project_name}-stream-generate-${var.environment}"
  description         = "Triggers synthetic IoT event generation every 5 minutes"
  schedule_expression = var.stream_schedule
  state               = "ENABLED"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "stream_generate" {
  rule      = aws_cloudwatch_event_rule.stream_generate.name
  target_id = "StreamGenerateLambda"
  arn       = var.stream_generate_function_arn
  role_arn  = aws_iam_role.eventbridge.arn
}

# ─── Glue Transform Schedule ─────────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "glue_transform" {
  name                = "${var.project_name}-glue-transform-${var.environment}"
  description         = "Triggers Glue transform job hourly"
  schedule_expression = var.transform_schedule
  state               = "ENABLED"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "glue_transform" {
  rule      = aws_cloudwatch_event_rule.glue_transform.name
  target_id = "GlueTransformJob"
  arn       = "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:job/${var.glue_job_name}"
  role_arn  = aws_iam_role.eventbridge.arn

  input = jsonencode({
    JobName        = var.glue_job_name
    JobParameters  = {}
  })
}

data "aws_caller_identity" "current" {}

# ─── EventBridge IAM Role ────────────────────────────────────────────────────
resource "aws_iam_role" "eventbridge" {
  name = "${var.project_name}-eventbridge-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "eventbridge_invoke" {
  name = "${var.project_name}-eventbridge-invoke-${var.environment}"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = [
          var.batch_ingest_function_arn,
          var.stream_generate_function_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "glue:StartJobRun"
        Resource = "arn:aws:glue:*:*:job/${var.glue_job_name}"
      }
    ]
  })
}
