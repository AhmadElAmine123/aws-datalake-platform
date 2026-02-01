variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "datalake_bucket_arn" {
  type = string
}

variable "athena_results_bucket_arn" {
  type = string
}

variable "logs_bucket_arn" {
  type = string
}

# ─── Lambda Execution Role ───────────────────────────────────────────────────
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Basic Lambda logging
resource "aws_iam_role_policy" "lambda_logging" {
  name = "${var.project_name}-lambda-logging-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-*"
    }]
  })
}

# S3 write to datalake raw/
resource "aws_iam_role_policy" "lambda_s3_write" {
  name = "${var.project_name}-lambda-s3-write-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject"
      ]
      Resource = "${var.datalake_bucket_arn}/raw/*"
    }]
  })
}

# KMS encrypt permission for Lambda
resource "aws_iam_role_policy" "lambda_kms" {
  name = "${var.project_name}-lambda-kms-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ]
      Resource = var.kms_key_arn
    }]
  })
}

# Kinesis Firehose PutRecord permission for stream Lambda
resource "aws_iam_role_policy" "lambda_firehose" {
  name = "${var.project_name}-lambda-firehose-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "firehose:PutRecord",
        "firehose:PutRecordBatch"
      ]
      Resource = "arn:aws:firehose:*:*:deliverystream/${var.project_name}-*"
    }]
  })
}

# ─── Glue Execution Role ─────────────────────────────────────────────────────
resource "aws_iam_role" "glue_execution" {
  name = "${var.project_name}-glue-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Glue: read raw/, write curated/
resource "aws_iam_role_policy" "glue_s3" {
  name = "${var.project_name}-glue-s3-${var.environment}"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.datalake_bucket_arn,
          "${var.datalake_bucket_arn}/raw/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.datalake_bucket_arn}/curated/*"
      },
      {
        # Glue needs to read its own scripts from S3
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.datalake_bucket_arn}/glue-scripts/*"
      }
    ]
  })
}

# Glue: KMS decrypt/encrypt
resource "aws_iam_role_policy" "glue_kms" {
  name = "${var.project_name}-glue-kms-${var.environment}"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      Resource = var.kms_key_arn
    }]
  })
}

# Glue: CloudWatch logs
resource "aws_iam_role_policy" "glue_logging" {
  name = "${var.project_name}-glue-logging-${var.environment}"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:log-group:/aws/glue/*"
    }]
  })
}

# Glue: Data Catalog permissions
resource "aws_iam_role_policy" "glue_catalog" {
  name = "${var.project_name}-glue-catalog-${var.environment}"
  role = aws_iam_role.glue_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "glue:CreateDatabase",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:DeleteTable",
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetTables",
        "glue:BatchGetTable"
      ]
      Resource = "*"
    }]
  })
}

# ─── Kinesis Firehose Role ───────────────────────────────────────────────────
resource "aws_iam_role" "firehose" {
  name = "${var.project_name}-firehose-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "${var.project_name}-firehose-s3-${var.environment}"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketAcl"
        ]
        Resource = [
          var.datalake_bucket_arn,
          "${var.datalake_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketAcl"
        ]
        Resource = [
          var.logs_bucket_arn,
          "${var.logs_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "firehose_kms" {
  name = "${var.project_name}-firehose-kms-${var.environment}"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = var.kms_key_arn
    }]
  })
}

resource "aws_iam_role_policy" "firehose_logging" {
  name = "${var.project_name}-firehose-logging-${var.environment}"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:log-group:/aws/firehose/*"
    }]
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "lambda_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "glue_role_arn" {
  value = aws_iam_role.glue_execution.arn
}

output "firehose_role_arn" {
  value = aws_iam_role.firehose.arn
}
