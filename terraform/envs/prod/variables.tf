variable "project_name" {
  type        = string
  description = "Project identifier used in all resource names"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'"
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "alert_email" {
  type        = string
  description = "Email for CloudWatch alarm SNS notifications"
}

variable "cities" {
  type = list(object({
    name      = string
    latitude  = number
    longitude = number
  }))
  description = "Cities for weather ingestion and IoT simulation"
}

variable "batch_schedule" {
  type        = string
  description = "EventBridge schedule for batch ingest"
}

variable "stream_schedule" {
  type        = string
  description = "EventBridge schedule for stream generation"
}

variable "transform_schedule" {
  type        = string
  description = "EventBridge schedule for Glue transform"
}
