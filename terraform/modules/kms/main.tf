variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── Data Lake KMS Key ───────────────────────────────────────────────────────
resource "aws_kms_key" "datalake" {
  description             = "${var.project_name} datalake encryption key (${var.environment})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.project_name}-datalake-key-policy"
    Statement = [
      {
        Sid       = "RootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowLambdaEncrypt"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowGlueEncrypt"
        Effect    = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowFirehoseEncrypt"
        Effect    = "Allow"
        Principal = { Service = "firehose.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowS3SSE"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_kms_alias" "datalake" {
  name          = "alias/${var.project_name}-datalake-${var.environment}"
  target_key_id = aws_kms_key.datalake.id
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "datalake_key_arn" {
  value = aws_kms_key.datalake.arn
}

output "datalake_key_id" {
  value = aws_kms_key.datalake.id
}
