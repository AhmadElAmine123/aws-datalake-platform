variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "firehose_role_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "datalake_bucket_id" {
  type = string
}

variable "logs_bucket_id" {
  type = string
}

# ─── Kinesis Firehose Delivery Stream ────────────────────────────────────────
resource "aws_kinesis_firehose_delivery_stream" "iot_sensors" {
  name         = "${var.project_name}-iot-firehose-${var.environment}"
  destination  = "s3"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  s3_configuration {
    role_arn           = var.firehose_role_arn
    bucket_id          = var.datalake_bucket_id
    prefix             = "raw/iot-sensors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_bucket_prefix = "firehose-errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{errors:type}/"
    buffering_size     = 5 # MB
    buffering_interval = 60 # seconds
    compression_format = "NONE" # JSON stays uncompressed for Glue readability

    cloudwatch_logging {
      enabled  = true
      log_type = "S3Delivery"
    }

    server_side_encryption {
      enabled = true
      type    = "aws:kms"
      key_arn = var.kms_key_arn
    }
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "firehose_name" {
  value = aws_kinesis_firehose_delivery_stream.iot_sensors.name
}

output "firehose_arn" {
  value = aws_kinesis_firehose_delivery_stream.iot_sensors.arn
}
