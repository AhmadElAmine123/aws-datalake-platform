variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "datalake_bucket_id" {
  type = string
}

variable "firehose_name" {
  type = string
}

variable "cities" {
  type = list(object({
    name      = string
    latitude  = number
    longitude = number
  }))
}

locals {
  batch_zip_path  = "${path.module}/batch_ingest.zip"
  stream_zip_path = "${path.module}/stream_generate.zip"
  scripts_root    = "${path.module}/../../scripts"
}

# ─── Package Lambda Functions ────────────────────────────────────────────────
resource "null_resource" "package_batch_ingest" {
  triggers = {
    source_hash = filesha256("${local.scripts_root}/batch_ingest/lambda_function.py")
  }
  provisioner "local-exec" {
    command = "cd ${local.scripts_root}/batch_ingest && zip -r ${local.batch_zip_path} ."
  }
}

resource "null_resource" "package_stream_generate" {
  triggers = {
    source_hash = filesha256("${local.scripts_root}/stream_generate/lambda_function.py")
  }
  provisioner "local-exec" {
    command = "cd ${local.scripts_root}/stream_generate && zip -r ${local.stream_zip_path} ."
  }
}

# ─── Batch Ingest Lambda (pulls from Open-Meteo) ────────────────────────────
resource "aws_lambda_function" "batch_ingest" {
  depends_on = [null_resource.package_batch_ingest]

  function_name = "${var.project_name}-batch-ingest-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 120
  memory_size   = 256
  architectures = ["x86_64"]

  filename         = local.batch_zip_path
  source_code_hash = filesha256(local.batch_zip_path)

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      DATALAKE_BUCKET = var.datalake_bucket_id
      ENVIRONMENT     = var.environment
      CITIES          = jsonencode(var.cities)
    }
  }

  logging_config {
    log_format = "JSON"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "batch_ingest" {
  name              = "/aws/lambda/${aws_lambda_function.batch_ingest.function_name}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

# ─── Stream Generate Lambda (pushes synthetic events to Firehose) ───────────
resource "aws_lambda_function" "stream_generate" {
  depends_on = [null_resource.package_stream_generate]

  function_name = "${var.project_name}-stream-generate-${var.environment}"
  role          = var.lambda_role_arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 120
  memory_size   = 256
  architectures = ["x86_64"]

  filename         = local.stream_zip_path
  source_code_hash = filesha256(local.stream_zip_path)

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      FIREHOSE_NAME   = var.firehose_name
      ENVIRONMENT     = var.environment
      CITIES          = jsonencode(var.cities)
      SENSORS_PER_CITY = "3"
    }
  }

  logging_config {
    log_format = "JSON"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "stream_generate" {
  name              = "/aws/lambda/${aws_lambda_function.stream_generate.function_name}"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "batch_ingest_function_name" {
  value = aws_lambda_function.batch_ingest.function_name
}

output "stream_generate_function_name" {
  value = aws_lambda_function.stream_generate.function_name
}

output "batch_ingest_function_arn" {
  value = aws_lambda_function.batch_ingest.arn
}

output "stream_generate_function_arn" {
  value = aws_lambda_function.stream_generate.arn
}
