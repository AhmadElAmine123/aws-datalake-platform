variable "environment" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "project_name" {
  type = string
}

locals {
  bucket_prefix = "${var.project_name}-${var.environment}"
}

# ─── Data Lake Bucket ────────────────────────────────────────────────────────
resource "aws_s3_bucket" "datalake" {
  bucket = "${local.bucket_prefix}-datalake"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "datalake"
  }
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket                          = aws_s3_bucket.datalake.id
  block_public_acls               = true
  block_public_policy             = true
  ignore_public_acls              = true
  restrict_public_buckets         = true
}

resource "aws_s3_bucket_policy" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.datalake.arn,
          "${aws_s3_bucket.datalake.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyIncorrectEncryption"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.datalake.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  rule {
    id     = "raw-to-ia"
    status = "Enabled"
    filter {
      prefix = "raw/"
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 365
    }
  }
}

# ─── Athena Query Results Bucket ─────────────────────────────────────────────
resource "aws_s3_bucket" "athena_results" {
  bucket = "${local.bucket_prefix}-athena-results"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "athena-results"
  }
}

resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                          = aws_s3_bucket.athena_results.id
  block_public_acls               = true
  block_public_policy             = true
  ignore_public_acls              = true
  restrict_public_buckets         = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    id     = "expire-results"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration {
      days = 7
    }
  }
}

# ─── CloudWatch Logs Bucket (for S3 access logs) ────────────────────────────
resource "aws_s3_bucket" "logs" {
  bucket = "${local.bucket_prefix}-logs"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "logs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                          = aws_s3_bucket.logs.id
  block_public_acls               = true
  block_public_policy             = true
  ignore_public_acls              = true
  restrict_public_buckets         = true
}

resource "aws_s3_bucket_logging" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  logging {
    target_bucket = aws_s3_bucket.logs.id
    target_prefix = "s3-access-logs/datalake/"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "datalake_bucket_id" {
  value = aws_s3_bucket.datalake.id
}

output "datalake_bucket_arn" {
  value = aws_s3_bucket.datalake.arn
}

output "athena_results_bucket_id" {
  value = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  value = aws_s3_bucket.athena_results.arn
}

output "logs_bucket_id" {
  value = aws_s3_bucket.logs.id
}
