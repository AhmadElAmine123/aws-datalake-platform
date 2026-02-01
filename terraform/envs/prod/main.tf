# ─── KMS Module ──────────────────────────────────────────────────────────────
module "kms" {
  source = "../../modules/kms"

  project_name = var.project_name
  environment  = var.environment
}

# ─── S3 Module ───────────────────────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  kms_key_arn  = module.kms.datalake_key_arn
}

# ─── IAM Module ──────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_name              = var.project_name
  environment               = var.environment
  kms_key_arn               = module.kms.datalake_key_arn
  datalake_bucket_arn       = module.s3.datalake_bucket_arn
  athena_results_bucket_arn = module.s3.athena_results_bucket_arn
  logs_bucket_arn           = module.s3.logs_bucket_arn
}

# ─── Kinesis Firehose Module ─────────────────────────────────────────────────
module "kinesis" {
  source = "../../modules/kinesis"

  project_name       = var.project_name
  environment        = var.environment
  firehose_role_arn  = module.iam.firehose_role_arn
  kms_key_arn        = module.kms.datalake_key_arn
  datalake_bucket_id = module.s3.datalake_bucket_id
  logs_bucket_id     = module.s3.logs_bucket_id
}

# ─── Lambda Module ───────────────────────────────────────────────────────────
module "lambda" {
  source = "../../modules/lambda"

  project_name       = var.project_name
  environment        = var.environment
  lambda_role_arn    = module.iam.lambda_role_arn
  kms_key_arn        = module.kms.datalake_key_arn
  datalake_bucket_id = module.s3.datalake_bucket_id
  firehose_name      = module.kinesis.firehose_name
  cities             = var.cities
}

# ─── Glue Module ─────────────────────────────────────────────────────────────
module "glue" {
  source = "../../modules/glue"

  project_name        = var.project_name
  environment         = var.environment
  glue_role_arn       = module.iam.glue_role_arn
  kms_key_arn         = module.kms.datalake_key_arn
  datalake_bucket_id  = module.s3.datalake_bucket_id
  datalake_bucket_arn = module.s3.datalake_bucket_arn
}

# ─── Athena Module ───────────────────────────────────────────────────────────
module "athena" {
  source = "../../modules/athena"

  project_name             = var.project_name
  environment              = var.environment
  athena_results_bucket_id = module.s3.athena_results_bucket_id
  kms_key_arn              = module.kms.datalake_key_arn
}

# ─── EventBridge Module ──────────────────────────────────────────────────────
module "eventbridge" {
  source = "../../modules/eventbridge"

  project_name                 = var.project_name
  environment                  = var.environment
  batch_ingest_function_arn    = module.lambda.batch_ingest_function_arn
  stream_generate_function_arn = module.lambda.stream_generate_function_arn
  glue_job_name                = module.glue.glue_job_name
  batch_schedule               = var.batch_schedule
  stream_schedule              = var.stream_schedule
  transform_schedule           = var.transform_schedule
}

# ─── Monitoring Module ───────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  project_name                  = var.project_name
  environment                   = var.environment
  alert_email                   = var.alert_email
  batch_ingest_function_name    = module.lambda.batch_ingest_function_name
  stream_generate_function_name = module.lambda.stream_generate_function_name
  glue_job_name                 = module.glue.glue_job_name
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "datalake_bucket" {
  value = module.s3.datalake_bucket_id
}

output "athena_workgroup" {
  value = module.athena.workgroup_name
}

output "glue_database" {
  value = module.glue.glue_database_name
}

output "sns_alerts_topic_arn" {
  value = module.monitoring.sns_topic_arn
}
