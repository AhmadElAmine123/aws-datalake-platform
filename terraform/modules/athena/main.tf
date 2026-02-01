variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "athena_results_bucket_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

# ─── Athena Workgroup ────────────────────────────────────────────────────────
resource "aws_athena_workgroup" "analytics" {
  name = "${var.project_name}-analytics-${var.environment}"

  configuration {
    enforce_result_configuration = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket_id}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key           = var.kms_key_arn
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "workgroup_name" {
  value = aws_athena_workgroup.analytics.name
}
